#!/usr/bin/env python3
"""
Generate compile_commands.json for C/C++ projects using bear.
This is a prerequisite for doom-emacs-lsp skill to work with C/C++ projects.
"""

import os
import sys
import subprocess
import argparse
import json
from pathlib import Path

def check_bear_installed():
    """Check if bear is installed."""
    try:
        result = subprocess.run(["which", "bear"], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ bear found: {result.stdout.strip()}")
            return True
        else:
            print("❌ bear not found in PATH")
            return False
    except Exception as e:
        print(f"❌ Error checking for bear: {e}")
        return False

def get_cpu_count():
    """Get number of CPU cores for parallel compilation."""
    try:
        import multiprocessing
        cores = multiprocessing.cpu_count()
        print(f"✅ System has {cores} CPU cores")
        return cores
    except:
        print("⚠ Could not determine CPU cores, using 4")
        return 4

def generate_for_make(project_path, clean=True, parallel=True):
    """Generate compile_commands.json for Makefile-based projects."""
    print(f"\n📦 Generating compile_commands.json for Makefile project: {project_path}")
    
    os.chdir(project_path)
    
    # Clean if requested
    if clean and os.path.exists("Makefile"):
        print("🧹 Cleaning project...")
        result = subprocess.run(["make", "clean"], capture_output=True, text=True)
        if result.returncode != 0:
            print(f"⚠ Clean command returned {result.returncode}")
            if result.stderr:
                print(f"   Stderr: {result.stderr[:200]}")
    
    # Generate compile_commands.json with bear
    cores = get_cpu_count() if parallel else 1
    cmd = ["bear", "--", "make", f"-j{cores}"]
    
    print(f"🚀 Running: {' '.join(cmd)}")
    print("   (This may take a while for large projects)")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        print("✅ Build successful with bear")
    else:
        print(f"❌ Build failed with exit code {result.returncode}")
        if result.stderr:
            print(f"   Error: {result.stderr[:500]}")
        return False
    
    return True

def generate_for_cmake(project_path, clean=True, parallel=True, use_ninja=True, use_cmake_option=True):
    """Generate compile_commands.json for CMake-based projects."""
    print(f"\n📦 Generating compile_commands.json for CMake project: {project_path}")
    
    os.chdir(project_path)
    
    # Create or clean build directory
    build_dir = "build"
    if clean and os.path.exists(build_dir):
        print(f"🧹 Removing existing build directory: {build_dir}")
        import shutil
        shutil.rmtree(build_dir)
    
    if not os.path.exists(build_dir):
        print(f"📁 Creating build directory: {build_dir}")
        os.makedirs(build_dir)
    
    os.chdir(build_dir)
    
    # Check if Ninja is available
    ninja_available = False
    if use_ninja:
        ninja_result = subprocess.run(["which", "ninja"], capture_output=True, text=True)
        ninja_available = ninja_result.returncode == 0
        
        if ninja_available:
            print(f"✅ Ninja available: {ninja_result.stdout.strip()}")
        else:
            print("⚠ Ninja not found, using default generator")
    
    # Method 1: Use CMake's built-in option (recommended for C++)
    if use_cmake_option:
        print("🔧 Using CMake's built-in compile commands export...")
        
        cmake_cmd = ["cmake", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON", ".."]
        if ninja_available:
            cmake_cmd.extend(["-G", "Ninja"])
            print(f"   With Ninja generator")
        
        result = subprocess.run(cmake_cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ CMake failed: {result.stderr[:500]}")
            return False
        
        print("✅ CMake configuration successful")
        
        # Also build the project (optional but good for verification)
        if parallel:
            cores = get_cpu_count()
            build_cmd = ["ninja", f"-j{cores}"] if ninja_available else ["make", f"-j{cores}"]
            print(f"🚀 Building project: {' '.join(build_cmd)}")
            result = subprocess.run(build_cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print("✅ Build successful")
            else:
                print(f"⚠ Build failed but compile_commands.json should still be valid")
        
        return True
    
    # Method 2: Use bear (for projects that don't support CMAKE_EXPORT_COMPILE_COMMANDS)
    else:
        print("🔧 Using bear to capture compile commands...")
        
        cmake_cmd = ["bear", "--", "cmake", ".."]
        if ninja_available:
            cmake_cmd.extend(["-G", "Ninja"])
            print(f"   With Ninja generator")
        
        result = subprocess.run(cmake_cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ CMake failed: {result.stderr[:500]}")
            return False
        
        # Run build with bear
        cores = get_cpu_count() if parallel else 1
        
        if ninja_available:
            cmd = ["bear", "--", "ninja", f"-j{cores}"]
            print(f"🚀 Running: {' '.join(cmd)} (Ninja)")
        else:
            cmd = ["bear", "--", "make", f"-j{cores}"]
            print(f"🚀 Running: {' '.join(cmd)} (Make)")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Build successful with bear")
        else:
            print(f"❌ Build failed: {result.stderr[:500]}")
            return False
        
        return True

def generate_for_meson(project_path, clean=True, parallel=True):
    """Generate compile_commands.json for Meson-based projects."""
    print(f"\n📦 Generating compile_commands.json for Meson project: {project_path}")
    
    os.chdir(project_path)
    
    # Create or clean build directory
    build_dir = "build"
    if clean and os.path.exists(build_dir):
        print(f"🧹 Removing existing build directory: {build_dir}")
        import shutil
        shutil.rmtree(build_dir)
    
    if not os.path.exists(build_dir):
        print(f"📁 Creating build directory: {build_dir}")
        os.makedirs(build_dir)
    
    os.chdir(build_dir)
    
    # Run meson with bear
    print("🔧 Running meson with bear...")
    result = subprocess.run(["bear", "--", "meson", ".."], capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Meson setup failed: {result.stderr[:500]}")
        return False
    
    # Run meson compile with bear
    cores = get_cpu_count() if parallel else 1
    cmd = ["bear", "--", "meson", "compile", f"-j{cores}"]
    
    print(f"🚀 Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        print("✅ Build successful with bear")
    else:
        print(f"❌ Build failed: {result.stderr[:500]}")
        return False
    
    return True

def detect_project_type(project_path):
    """Detect the build system used by the project."""
    project_path = Path(project_path)
    
    if (project_path / "CMakeLists.txt").exists():
        return "cmake"
    elif (project_path / "meson.build").exists():
        return "meson"
    elif (project_path / "Makefile").exists():
        return "make"
    elif (project_path / "configure").exists() or (project_path / "configure.ac").exists():
        return "autotools"
    else:
        # Check for any .c or .cpp files
        c_files = list(project_path.glob("**/*.c")) + list(project_path.glob("**/*.cpp"))
        if c_files:
            return "unknown_c"  # C/C++ project but build system unknown
        return "unknown"

def verify_compile_commands(project_path, build_system):
    """Verify that compile_commands.json was generated correctly."""
    # For CMake projects, compile_commands.json is in build directory
    if build_system == "cmake":
        compile_file = Path(project_path) / "build" / "compile_commands.json"
    else:
        compile_file = Path(project_path) / "compile_commands.json"
    
    if not compile_file.exists():
        print(f"❌ compile_commands.json was not generated at {compile_file}")
        return False
    
    try:
        with open(compile_file, 'r') as f:
            data = json.load(f)
        
        print(f"✅ compile_commands.json generated successfully")
        print(f"   Contains {len(data)} compile commands")
        
        # Check a few entries
        if data:
            sample = data[0]
            print(f"   Sample entry:")
            print(f"     File: {sample.get('file', 'N/A')}")
            print(f"     Command: {' '.join(sample.get('arguments', []))[:100]}...")
        
        # Check for C++ specific flags
        cpp_flags = []
        for entry in data[:10]:  # Check first 10 entries
            args = entry.get('arguments', [])
            cpp_flags.extend([arg for arg in args if any(flag in arg for flag in ['-std=c++', '-std=gnu++'])])
        
        if cpp_flags:
            print(f"   C++ standard flags found: {set(cpp_flags)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error reading compile_commands.json: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description="Generate compile_commands.json for C/C++ projects using bear"
    )
    parser.add_argument(
        "project_path",
        help="Path to the C/C++ project directory"
    )
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Skip cleaning before build"
    )
    parser.add_argument(
        "--no-parallel",
        action="store_true",
        help="Disable parallel compilation"
    )
    parser.add_argument(
        "--build-system",
        choices=["auto", "make", "cmake", "meson"],
        default="auto",
        help="Specify build system (default: auto-detect)"
    )
    parser.add_argument(
        "--no-ninja",
        action="store_true",
        help="Disable Ninja generator for CMake projects"
    )
    parser.add_argument(
        "--use-bear",
        action="store_true",
        help="Use bear instead of CMake's built-in compile commands export"
    )
    
    args = parser.parse_args()
    
    project_path = Path(args.project_path).absolute()
    
    if not project_path.exists():
        print(f"❌ Project path does not exist: {project_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("Doom Emacs LSP: Generate compile_commands.json")
    print("=" * 70)
    print(f"Project: {project_path}")
    
    # Check if bear is installed
    if not check_bear_installed():
        print("\n📦 Please install bear first:")
        print("  Ubuntu/Debian: sudo apt-get install bear")
        print("  macOS: brew install bear")
        print("  From source: https://github.com/rizsotto/Bear")
        sys.exit(1)
    
    # Detect or use specified build system
    if args.build_system == "auto":
        build_system = detect_project_type(project_path)
        print(f"🔍 Detected build system: {build_system}")
    else:
        build_system = args.build_system
        print(f"🔧 Using specified build system: {build_system}")
    
    # Generate compile_commands.json
    success = False
    if build_system == "make":
        success = generate_for_make(
            project_path,
            clean=not args.no_clean,
            parallel=not args.no_parallel
        )
    elif build_system == "cmake":
        success = generate_for_cmake(
            project_path,
            clean=not args.no_clean,
            parallel=not args.no_parallel,
            use_ninja=not args.no_ninja,
            use_cmake_option=not args.use_bear  # Use CMake option by default, bear if specified
        )
    elif build_system == "meson":
        success = generate_for_meson(
            project_path,
            clean=not args.no_clean,
            parallel=not args.no_parallel
        )
    elif build_system == "autotools":
        print("⚠ Autotools detected - manual steps required:")
        print("  1. Run ./configure")
        print("  2. Run: bear -- make -j$(nproc)")
        success = False
    elif build_system == "unknown_c":
        print("⚠ C/C++ project detected but build system unknown")
        print("  Try one of:")
        print("    --build-system=make   (for Makefile projects)")
        print("    --build-system=cmake  (for CMake projects)")
        print("    --build-system=meson  (for Meson projects)")
        success = False
    else:
        print("❌ Could not detect build system")
        print("  Make sure the project has one of:")
        print("    - Makefile")
        print("    - CMakeLists.txt")
        print("    - meson.build")
        success = False
    
    # Verify the result
    if success:
        print("\n" + "=" * 70)
        print("Verification")
        print("=" * 70)
        
        verify_compile_commands(project_path)
        
        print("\n" + "=" * 70)
        print("✅ Success! compile_commands.json is ready")
        print("=" * 70)
        print("\nNow you can use doom-emacs-lsp skill with this project:")
        print(f"  from lsp_unified import create_lsp_client")
        print(f"  with create_lsp_client('{project_path}', 'c') as client:")
        print(f"      result = client.find_references('src/file.c', 10, 5)")
    else:
        print("\n" + "=" * 70)
        print("❌ Failed to generate compile_commands.json")
        print("=" * 70)
        print("\nTroubleshooting:")
        print("1. Make sure bear is installed correctly")
        print("2. Check that the project builds normally")
        print("3. Try running the build command manually:")
        print("   cd /path/to/project")
        print("   bear -- make -j$(nproc)")
        print("4. Check bear documentation: https://github.com/rizsotto/Bear")
        
        sys.exit(1)

if __name__ == "__main__":
    main()