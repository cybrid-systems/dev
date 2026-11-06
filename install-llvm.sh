#!/bin/bash
# Install the latest LLVM official release, then keep only the pieces Aura
# links and runs. The upstream tarball is ~12GB unpacked (Flang, MLIR, LLDB,
# every target's static archives, and statically linked tools). Aura needs:
#   - clang/clang++            module BMI build and clang-tidy compile DB
#   - clang-format, clang-tidy gate
#   - llvm-cov, llvm-profdata  ./build.py coverage
#   - llvm-symbolizer          ASan/UBSan/TSan stacks
#   - ld.lld                   link fallback when mold cannot be used
#   - llvm-config + the static libs for
#       core orcjit native nativecodegen mc
#     (CMakeLists.txt llvm_map_components_to_libnames)
#   - lib/clang/<major>        clang resource directory (builtins + headers)
#   - include/llvm, include/clang
set -euo pipefail

LLVM_VERSION="${LLVM_VERSION:-23.1.5}"
PREFIX="${LLVM_PREFIX:-/usr/local}"
COMPONENTS=(core orcjit native nativecodegen mc)

echo "=== LLVM ${LLVM_VERSION} (Aura subset) ==="

arch=$(uname -m)
case "$arch" in
    x86_64) llvm_arch=X64 ;;
    aarch64 | arm64) llvm_arch=ARM64 ;;
    *)
        echo "unsupported architecture: $arch" >&2
        exit 1
        ;;
esac

if [ -n "${LLVM_STAGE:-}" ]; then
    stage="$LLVM_STAGE"
    download_root=""
else
    download_root=$(mktemp -d)
    stage="$download_root"
    tarball="$download_root/llvm.tar.xz"
    # Tsinghua GitHub Release mirror. The release directory name is
    # "LLVM <version>/" (%20 for the space, %2F for the slash).
    url="https://mirrors.tuna.tsinghua.edu.cn/github-release/llvm/llvm-project/LLVM%20${LLVM_VERSION}%2FLLVM-${LLVM_VERSION}-Linux-${llvm_arch}.tar.xz"
    echo "downloading ${url}"
    curl -fL --retry 5 --retry-delay 2 -o "$tarball" "$url"
    python3 - "$tarball" "$stage/root" <<'PY'
import os
import sys
import tarfile

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
with tarfile.open(src, "r:xz") as tar:
    members = []
    for member in tar.getmembers():
        name = member.name[2:] if member.name.startswith("./") else member.name
        parts = name.split("/", 1)
        if len(parts) == 2 and parts[1]:
            member.name = parts[1]
            members.append(member)
    tar.extractall(path=dst, members=members)
PY
    rm -f "$tarball"
    stage="$download_root/root"
fi

if [ ! -x "$stage/bin/llvm-config" ]; then
    echo "llvm-config missing under $stage" >&2
    exit 1
fi

major="${LLVM_VERSION%%.*}"
install_file() {
    local rel="$1"
    local src="$stage/$rel"
    local dst="$PREFIX/$rel"
    if [ ! -e "$src" ]; then
        echo "missing $src" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -a "$src" "$dst"
}

install_file "bin/clang-${major}"
ln -sfn "clang-${major}" "$PREFIX/bin/clang"
ln -sfn clang "$PREFIX/bin/clang++"
install_file bin/clang-format
install_file bin/clang-tidy
install_file bin/lld
ln -sfn lld "$PREFIX/bin/ld.lld"
for tool in llvm-config llvm-cov llvm-profdata llvm-symbolizer; do
    install_file "bin/$tool"
done

for dir in llvm llvm-c clang clang-c; do
    install_file "include/$dir"
done
install_file lib/cmake/llvm
install_file "lib/clang/${major}"

read -r -a libs <<<"$("$stage/bin/llvm-config" --link-static --libnames "${COMPONENTS[@]}")"
if [ "${#libs[@]}" -lt 8 ]; then
    echo "llvm-config --libnames returned too few libraries: ${libs[*]:-}" >&2
    exit 1
fi
for lib in "${libs[@]}"; do
    install_file "lib/$lib"
done

# find_package(LLVM) refuses to configure if any imported target's file is
# missing, including opt, llc, Flang, and Polly. Drop those entries. Targets
# Aura links still have their static archives and IMPORTED_LOCATION.
python3 - "$PREFIX" <<'PY'
import sys
from pathlib import Path

prefix = Path(sys.argv[1])
exports = prefix / "lib/cmake/llvm/LLVMExports-release.cmake"
text = exports.read_text()
marker = "# Import target \""
head, _, rest = text.partition(marker)
blocks = rest.split(marker)
kept = []
dropped = 0
for block in blocks:
    if not block:
        continue
    body = marker + block
    missing = False
    for line in body.splitlines():
        token = '"${_IMPORT_PREFIX}'
        if token not in line:
            continue
        rel = line.split(token, 1)[1]
        rel = rel.split('"', 1)[0]
        if not (prefix / rel.lstrip("/")).exists():
            missing = True
            break
    if missing:
        dropped += 1
        continue
    kept.append(body)
exports.write_text(head + "".join(kept))
print(f"LLVMExports-release.cmake: dropped {dropped} targets with missing files")
PY

if [ -n "$download_root" ]; then
    rm -rf "$download_root"
fi

echo "=== LLVM subset layout ==="
du -sh "$PREFIX/bin" "$PREFIX/lib" "$PREFIX/include" "$PREFIX/lib/clang/${major}" || true
echo "static libs kept: ${#libs[@]}"

export PATH="$PREFIX/bin:${PATH}"
missing=0
for bin in \
    "$PREFIX/bin/clang-${major}" \
    "$PREFIX/bin/clang-format" \
    "$PREFIX/bin/clang-tidy" \
    "$PREFIX/bin/lld" \
    "$PREFIX/bin/llvm-config" \
    "$PREFIX/bin/llvm-cov" \
    "$PREFIX/bin/llvm-profdata" \
    "$PREFIX/bin/llvm-symbolizer"
do
    [ -f "$bin" ] && [ ! -L "$bin" ] || continue
    ldd_out=$(ldd "$bin" 2>/dev/null || true)
    case "$ldd_out" in
        *"not found"*)
            echo "unresolved libraries: $bin" >&2
            printf '%s\n' "$ldd_out" | grep 'not found' >&2 || true
            missing=1
            ;;
    esac
done
if [ "$missing" -ne 0 ]; then
    exit 1
fi

read -r -a installed_libs <<<"$(llvm-config --link-static --libnames "${COMPONENTS[@]}")"
for lib in "${installed_libs[@]}"; do
    if [ ! -f "$PREFIX/lib/$lib" ]; then
        echo "installed llvm-config wants missing $PREFIX/lib/$lib" >&2
        exit 1
    fi
done

smoke=$(mktemp -d)
cat >"$smoke/t.c" <<'EOF'
#include <stdio.h>
int main(void) {
    puts("ok");
    return 0;
}
EOF
cat >"$smoke/t.cpp" <<'EOF'
#include <stdio.h>
int main() {
    puts("ok");
    return 0;
}
EOF
clang -fuse-ld=lld "$smoke/t.c" -o "$smoke/t"
clang++ -fuse-ld=lld "$smoke/t.cpp" -o "$smoke/txx"
"$smoke/t" >/dev/null
"$smoke/txx" >/dev/null
rm -rf "$smoke"

clang --version | head -n 1
clang-format --version | head -n 1
clang-tidy --version | head -n 1
llvm-cov --version | head -n 1
llvm-profdata --version | head -n 1
ld.lld --version | head -n 1
echo "=== LLVM ${LLVM_VERSION} subset ready ==="
