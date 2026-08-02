#!/usr/bin/env python3
"""generate_compile_commands.py — auto-detect build system and emit compile_commands.json.

Replacement for the legacy Racket version. Detects CMake / Make / Ninja
projects, runs the appropriate generator (cmake with
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON, or `bear -- make`), and copies the
resulting compile_commands.json to the project root.

Usage:
  python3 generate_compile_commands.py <project-root> [--build-system cmake|make|auto] [--force]
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


def detect_build_system(root: Path) -> str:
    if (root / "CMakeLists.txt").exists():
        return "cmake"
    if (root / "Makefile").exists() or (root / "makefile").exists():
        return "make"
    if (root / "build.ninja").exists():
        return "ninja"
    return "unknown"


def run_cmd(cmd: str, cwd: Path) -> list[str]:
    """Run `cmd` (passed to /bin/sh -c) and return its stdout lines."""
    proc = subprocess.Popen(
        ["/bin/sh", "-c", cmd],
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    out, _ = proc.communicate()
    return out.splitlines() if out else []


def generate_cmake(root: Path) -> bool:
    build_dir = root / "build"
    build_dir.mkdir(exist_ok=True)
    ninja = shutil.which("ninja") or os.path.exists("/usr/bin/ninja")
    gen = "Ninja" if ninja else "Unix Makefiles"

    cmake_cmd = (
        f'cmake -S "{root}" -B "{build_dir}" '
        f'-DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G "{gen}"'
    )
    print(f"[cmake] {cmake_cmd}")
    for line in run_cmd(cmake_cmd, root):
        print(line)

    if ninja:
        ninja_cmd = f'ninja -C "{build_dir}" -j4'
        print(f"[ninja] {ninja_cmd}")
        for line in run_cmd(ninja_cmd, root):
            print(line)

    src_cc = build_dir / "compile_commands.json"
    dest_cc = root / "compile_commands.json"
    if src_cc.exists():
        shutil.copyfile(src_cc, dest_cc)
        print(f"[OK] compile_commands.json -> {dest_cc}")
        return True
    print(f"[ERROR] compile_commands.json not found in {build_dir}")
    return False


def generate_make(root: Path) -> bool:
    bear = shutil.which("bear")
    if not bear:
        print("[ERROR] bear not found in PATH — install with `apt install bear` or `brew install bear`")
        return False
    bear_cmd = f'bear -- make -C "{root}" -j4'
    print(f"[bear] {bear_cmd}")
    for line in run_cmd(bear_cmd, root):
        print(line)
    cc = root / "compile_commands.json"
    if cc.exists():
        print(f"[OK] compile_commands.json -> {cc}")
        return True
    print("[ERROR] bear failed to produce compile_commands.json")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Auto-detect build system and generate compile_commands.json for clangd.",
    )
    parser.add_argument("root", help="Project root directory")
    parser.add_argument(
        "--build-system",
        choices=["cmake", "make", "auto"],
        default="auto",
        help="Force a specific build system (default: auto-detect)",
    )
    parser.add_argument(
        "--force", "--overwrite",
        action="store_true",
        dest="force",
        help="Overwrite an existing compile_commands.json",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory", file=sys.stderr)
        return 1

    dest_cc = root / "compile_commands.json"
    if dest_cc.exists() and not args.force:
        print(f"[INFO] compile_commands.json already exists at {dest_cc}")
        print("Use --force or --overwrite to regenerate.")
        return 0
    if dest_cc.exists() and args.force:
        print(f"[INFO] --force: overwriting existing compile_commands.json")
        dest_cc.unlink()

    detected = args.build_system if args.build_system != "auto" else detect_build_system(root)
    print(f"[INFO] Build system: {detected}")

    if detected == "cmake":
        success = generate_cmake(root)
    elif detected == "make":
        success = generate_make(root)
    else:
        print("[ERROR] Unknown build system.")
        print("Create CMakeLists.txt or Makefile, then run:")
        print("  mkdir build && cd build")
        print("  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..")
        return 1

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())