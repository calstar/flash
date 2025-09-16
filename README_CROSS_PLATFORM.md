# Cross-Platform Flash Installation System

A unified installation system for setting up the flash environment across multiple platforms: macOS (Homebrew), Debian/Ubuntu (apt), and Windows (Chocolatey/Winget).

## Features

- **Cross-Platform Support**: Works on macOS, Linux (Debian/Ubuntu), and Windows
- **Simplified Dependencies**: Removed FSW cloning, GStreamer pipeline, CUDA, and libgeographic dependencies
- **OpenCV Support**: Installs OpenCV with essential computer vision capabilities
- **Python Environment**: Sets up isolated Python virtual environment with optional Python 3.8.10 compilation
- **Package Manager Abstraction**: Automatically detects and uses appropriate package manager
- **Comprehensive Logging**: Detailed installation logs for troubleshooting
- **Development Tools**: Optional bashdb debugger installation
- **Database Support**: Optional elodin-db installation
- **Startup Integration**: Automatic startup.sh setup for environment activation
- **Configuration System**: Flexible configuration via install_config.sh

## Supported Platforms

| Platform | Package Manager | Status | Python Compilation | Elodin Support |
|----------|----------------|--------|-------------------|----------------|
| macOS (Intel/Apple Silicon) | Homebrew | ✅ Supported | ❌ Not Available | ✅ Full Support |
| Ubuntu 18.04+ | apt | ✅ Supported | ✅ Available | ✅ Full Support |
| Debian 10+ | apt | ✅ Supported | ✅ Available | ✅ Full Support |
| Windows 10/11 (WSL) | apt | ✅ Recommended | ✅ Available | ✅ Full Support |
| Windows 10/11 (Native) | Chocolatey/Winget | ⚠️ Limited | ❌ Not Available | ⚠️ Editor Only |

## Quick Start

### macOS
```bash
# Make executable and run
chmod +x install.sh
./install.sh
```

### Linux (Ubuntu/Debian)
```bash
# Make executable and run
chmod +x install.sh
./install.sh
```

### Windows

**Automatic WSL Installation (Recommended):**
```powershell
# PowerShell - Automatically installs WSL and runs Linux installer
.\install.ps1

# Or Command Prompt - Automatically installs WSL and runs Linux installer
install.bat
```

**Manual WSL Setup:**
```bash
# Install WSL first, then:
wsl
cd /mnt/c/path/to/flash
./install.sh
```

**Native Windows (Limited):**
```powershell
# PowerShell (Limited functionality, skips WSL)
.\install.ps1 -SkipWSL

# Or Command Prompt (Limited functionality, skips WSL)
install.bat skip

# Or Windows-specific installer (Recommends WSL)
install_windows.bat
```

## Configuration

The installer can be customized using `install_config.sh`:

```bash
# Python version to compile from source (Linux only)
PYTHON_VERSION="3.8.10"

# Development tools
INSTALL_BASHDB=false          # Set to true to install bash debugger
INSTALL_ELODIN_EDITOR=true    # Set to false to skip elodin editor installation
INSTALL_ELODIN_DB=true        # Set to false to skip elodin-db installation

# Platform-specific settings
ENABLE_PYTHON_COMPILATION=true  # Set to false to skip Python compilation on Linux
ENABLE_STARTUP_INTEGRATION=true # Set to false to skip startup.sh integration
ENABLE_SUDO_SETUP=true         # Set to false to skip sudo permissions setup
```

## What Gets Installed

### System Packages
- **Build Tools**: CMake, Git, Python 3.9+
- **OpenCV**: Computer vision library
- **Development Tools**: pkg-config, development headers, autotools (for bashdb)
- **Linux Extras**: Comprehensive development libraries, Qt5, Boost, FFTW, etc.

### Python Packages
- **Core Libraries**: NumPy, Matplotlib, Pandas, SciPy
- **Graphics**: Pygame, PyOpenGL
- **Machine Learning**: scikit-learn, Numba
- **Utilities**: TOML, PySerial, gprof2dot

### Optional Tools
- **bashdb**: Bash script debugger (configurable)
- **elodin-db**: Database management system (configurable)

## Installation Process

1. **Platform Detection**: Automatically detects your operating system and architecture
2. **Package Manager Setup**: Installs Homebrew (macOS), uses apt (Linux), or installs Chocolatey (Windows)
3. **System Packages**: Installs required system dependencies
4. **Python Environment**: Creates and activates virtual environment
5. **Python Packages**: Installs Python requirements
6. **OpenCV Installation**: Installs OpenCV via pip or package manager

## Directory Structure

```
flash/
├── install.sh              # Unix/Linux/macOS installer
├── install.bat             # Windows batch installer
├── install.ps1             # Windows PowerShell installer
├── base_requirements.txt   # Python requirements
├── flash_install.log       # Installation log
├── venv/                   # Python virtual environment
└── README_CROSS_PLATFORM.md
```

## Usage After Installation

### Activate Python Environment

**macOS/Linux:**
```bash
source venv/bin/activate
```

**Windows:**
```cmd
venv\Scripts\activate
```

**Windows PowerShell:**
```powershell
.\venv\Scripts\Activate.ps1
```

### Verify Installation

```python
import cv2
import numpy as np
import matplotlib.pyplot as plt

print(f"OpenCV version: {cv2.__version__}")
print(f"NumPy version: {np.__version__}")
print("Installation successful!")
```

## Troubleshooting

### Common Issues

1. **Permission Errors (macOS/Linux)**
   - Don't run with `sudo` unless absolutely necessary
   - Ensure you have write permissions to the installation directory

2. **Python Not Found (Windows)**
   - Restart your terminal after installation
   - Ensure Python is added to your PATH

3. **OpenCV Installation Fails**
   - Try installing system OpenCV first: `brew install opencv` (macOS) or `sudo apt install libopencv-dev` (Linux)
   - Then run the installer again

4. **Virtual Environment Issues**
   - Delete the `venv` directory and run the installer again
   - Ensure Python 3.9+ is installed

### Logs

Check `flash_install.log` for detailed installation logs and error messages.

## Platform-Specific Notes

### macOS
- Requires Xcode Command Line Tools: `xcode-select --install`
- Homebrew will be installed if not present
- Supports both Intel and Apple Silicon Macs

### Linux
- Requires `sudo` access for package installation
- Tested on Ubuntu 18.04+ and Debian 10+
- May require additional dependencies on older distributions

### Windows
- Requires PowerShell 5.1+ or Windows Terminal
- Chocolatey or Winget package manager will be installed
- May require running as Administrator for initial setup

## Development

### Adding New Dependencies

1. **System Packages**: Add to the appropriate package manager section in the installer
2. **Python Packages**: Add to `base_requirements.txt`

### Testing

Test the installer on each platform:
- macOS: Test on both Intel and Apple Silicon
- Linux: Test on Ubuntu and Debian
- Windows: Test with both Chocolatey and Winget

## Migration from Legacy System

This new system replaces the following legacy scripts:
- `jetson_initial_flash.sh` (Jetson-specific)
- `jetson_install_fsw.sh` (FSW cloning removed)
- `jetson_install_opencvcuda.sh` (CUDA removed)
- `jetson_install_pyreqs_base.sh` (Simplified)
- `groundstation_install_*.sh` (Unified)

## Future Enhancements

- [ ] Add FSW repository cloning (when ready)
- [ ] Add optional CUDA support for GPU acceleration
- [ ] Add GStreamer pipeline support
- [ ] Add libgeographic support
- [ ] Add Docker support for containerized installation
- [ ] Add CI/CD testing for all platforms
