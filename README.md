# Flash - Cross-Platform Installer System

A comprehensive cross-platform installation system for embedded development environments, supporting macOS, Linux (Debian/Ubuntu), and Windows.

## Quick Start

### macOS
```bash
curl -fsSL https://raw.githubusercontent.com/calstar/flash/main/install.sh | bash
```

### Linux (Debian/Ubuntu/WSL)
```bash
curl -fsSL https://raw.githubusercontent.com/calstar/flash/main/install.sh | bash
```

### Windows
```powershell
# Recommended: Use WSL for full functionality
iwr -useb https://raw.githubusercontent.com/calstar/flash/main/install.ps1 | iex

# Or download and run install.bat
```

## Features

- **Cross-Platform Support**: macOS, Debian, Ubuntu, Windows (WSL recommended)
- **Python Environment**: Virtual environment setup with required packages
- **OpenCV Installation**: Without CUDA dependencies for broader compatibility
- **Elodin Integration**: Editor and database tools for development
- **Jetson Support**: Specialized scripts for NVIDIA Jetson devices
- **Development Tools**: Bash debugger, comprehensive logging

## Documentation

See [README_CROSS_PLATFORM.md](README_CROSS_PLATFORM.md) for detailed installation instructions and configuration options.

