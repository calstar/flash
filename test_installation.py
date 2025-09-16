#!/usr/bin/env python3
"""
Test script to verify the flash installation
"""

import sys
import importlib
import subprocess
import platform

def test_python_version():
    """Test Python version"""
    print("Testing Python version...")
    version = sys.version_info
    if version.major >= 3 and version.minor >= 9:
        print(f"✅ Python {version.major}.{version.minor}.{version.micro} - OK")
        return True
    else:
        print(f"❌ Python {version.major}.{version.minor}.{version.micro} - Requires Python 3.9+")
        return False

def test_package_import(package_name, display_name=None):
    """Test if a package can be imported"""
    if display_name is None:
        display_name = package_name
    
    try:
        module = importlib.import_module(package_name)
        version = getattr(module, '__version__', 'Unknown')
        print(f"✅ {display_name} {version} - OK")
        return True
    except ImportError as e:
        print(f"❌ {display_name} - Import failed: {e}")
        return False

def test_opencv():
    """Test OpenCV specifically"""
    print("Testing OpenCV...")
    try:
        import cv2
        version = cv2.__version__
        print(f"✅ OpenCV {version} - OK")
        
        # Test basic OpenCV functionality
        import numpy as np
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        print("✅ OpenCV basic functionality - OK")
        return True
    except ImportError as e:
        print(f"❌ OpenCV - Import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ OpenCV - Functionality test failed: {e}")
        return False

def test_platform_specific():
    """Test platform-specific packages"""
    print("Testing platform-specific packages...")
    
    system = platform.system().lower()
    
    if system == "darwin":  # macOS
        print("Testing macOS-specific packages...")
        # Add macOS-specific tests if needed
        return True
    elif system == "linux":
        print("Testing Linux-specific packages...")
        # Add Linux-specific tests if needed
        return True
    elif system == "windows":
        print("Testing Windows-specific packages...")
        # Add Windows-specific tests if needed
        return True
    else:
        print(f"Unknown platform: {system}")
        return False

def test_system_tools():
    """Test system tools"""
    print("Testing system tools...")
    
    tools = ['cmake', 'git', 'python3']
    if platform.system().lower() == 'windows':
        tools = ['cmake', 'git', 'python']
    
    all_ok = True
    for tool in tools:
        try:
            result = subprocess.run([tool, '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_line = result.stdout.split('\n')[0]
                print(f"✅ {tool} - {version_line}")
            else:
                print(f"❌ {tool} - Command failed")
                all_ok = False
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print(f"❌ {tool} - Not found or timeout")
            all_ok = False
    
    return all_ok

def main():
    """Run all tests"""
    print("=" * 50)
    print("Flash Installation Test")
    print("=" * 50)
    print(f"Platform: {platform.system()} {platform.machine()}")
    print(f"Python: {sys.executable}")
    print("=" * 50)
    
    tests = [
        ("Python Version", test_python_version),
        ("System Tools", test_system_tools),
        ("OpenCV", test_opencv),
        ("NumPy", lambda: test_package_import('numpy')),
        ("Matplotlib", lambda: test_package_import('matplotlib')),
        ("Pandas", lambda: test_package_import('pandas')),
        ("SciPy", lambda: test_package_import('scipy')),
        ("Scikit-learn", lambda: test_package_import('sklearn', 'scikit-learn')),
        ("Pygame", lambda: test_package_import('pygame')),
        ("PyOpenGL", lambda: test_package_import('OpenGL', 'PyOpenGL')),
        ("Numba", lambda: test_package_import('numba')),
        ("PySerial", lambda: test_package_import('serial', 'PySerial')),
        ("Platform Specific", test_platform_specific),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{test_name}:")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} - Test failed with exception: {e}")
            results.append((test_name, False))
    
    print("\n" + "=" * 50)
    print("Test Summary")
    print("=" * 50)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name}: {status}")
        if result:
            passed += 1
    
    print("=" * 50)
    print(f"Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Installation is successful.")
        return 0
    else:
        print("⚠️  Some tests failed. Check the output above for details.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
