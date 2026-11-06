# dev

Ubuntu 26.10 image with the packages required to build [Aura](https://github.com/cybrid-systems/aura).

The image keeps GCC 16.2, the newest CMake release, Ninja, and the newest LLVM,
then drops everything Aura's build does not run. The upstream LLVM tarball is
about 12GB unpacked. This image keeps roughly 1GB of it: `clang`, `clang-format`,
`clang-tidy`, `llvm-cov`, `llvm-profdata`, `llvm-symbolizer`, `ld.lld`, and the
static libraries behind `core orcjit native nativecodegen mc`.

| Tool | Version | Source |
| --- | --- | --- |
| Ubuntu | 26.10 | base image |
| GCC / G++ | 16.2 | Ubuntu `gcc-16` / `g++-16` |
| CMake | 4.5.0-rc3 | Kitware release (newest; 4.4.5 is the newest stable) |
| Ninja | 1.13.2 | Ubuntu `ninja-build` (same as upstream) |
| LLVM / Clang | 23.1.5 | upstream tarball, subset installed by `install-llvm.sh` |
| mold | Ubuntu 26.10 | `mold` package, linker Aura prefers |
| libgit2 | Ubuntu 26.10 | `libgit2-dev` |
| Python | Ubuntu 26.10 | `ruff==0.17.3`, `pexpect==4.9.0` |

Not in the image: Emacs, Node, pnpm, Rust, OpenClaw, Flang, MLIR, LLDB.
`build-emacs.sh` and `install-languages.sh` are unused by this Dockerfile.

A build needs temporary disk for the full LLVM tarball (about 15GB) in the
LLVM `RUN`. The unused files are deleted in that same instruction, so they
are not part of the image layer.

## build

```bash
docker buildx create --use
docker buildx build --platform linux/arm64 -t aura-min:local . --load
docker buildx build --platform linux/amd64 -t aura-min:local . --load
```

Override a pin at build time:

```bash
docker build \
  --build-arg LLVM_VERSION=23.1.5 \
  --build-arg CMAKE_VERSION=4.5.0-rc3 \
  -t aura-min:local .
```

## test

```bash
IMAGE=aura-min:local ./test-image.sh
```

## run

```bash
docker run -d -it --name aura-dev \
  --net host \
  --cap-add=SYS_PTRACE \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  -v "$(pwd)":/home/dev/code \
  -w /home/dev/code \
  aura-min:local

docker exec -it -u dev aura-dev /bin/zsh -l
```
