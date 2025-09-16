#!/bin/bash

# Jetson OpenCV Installation Script
# Installs OpenCV without CUDA dependencies for broader compatibility

set -e

# Configuration
OPENCV_VERSION="4.8.0"
INSTALL_PREFIX="/usr/local"
PYTHON_VERSION="3.8"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[OPENCV]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[OPENCV]${NC} $1"
}

log_error() {
    echo -e "${RED}[OPENCV]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check available space
check_space() {
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=2000000  # 2GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_warn "Low disk space detected. Available: ${available_space}KB, Required: ${required_space}KB"
        log_warn "Installation may fail or take longer than expected"
    else
        log "Disk space check passed. Available: ${available_space}KB"
    fi
}

# Install system dependencies
install_dependencies() {
    log "Installing OpenCV dependencies..."
    
    apt update
    apt install -y \
        build-essential \
        cmake \
        git \
        pkg-config \
        libjpeg-dev \
        libtiff5-dev \
        libpng-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libv4l-dev \
        libxvidcore-dev \
        libx264-dev \
        libgtk-3-dev \
        libatlas-base-dev \
        gfortran \
        python3-dev \
        python3-numpy \
        libtbb2 \
        libtbb-dev \
        libdc1394-22-dev \
        libopenexr-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev
}

# Install OpenCV via apt (faster, recommended)
install_opencv_apt() {
    log "Installing OpenCV via apt..."
    
    apt update
    apt install -y \
        libopencv-dev \
        python3-opencv \
        libopencv-contrib-dev
    
    # Install Python OpenCV packages
    pip3 install opencv-python opencv-contrib-python
    
    log "OpenCV installed successfully via apt"
}

# Verify OpenCV installation
verify_opencv() {
    log "Verifying OpenCV installation..."
    
    # Test C++ installation
    if pkg-config --exists opencv4; then
        local version=$(pkg-config --modversion opencv4)
        log "OpenCV C++ version: $version"
    else
        log_warn "OpenCV C++ not found via pkg-config"
    fi
    
    # Test Python installation
    if python3 -c "import cv2; print('OpenCV Python version:', cv2.__version__)" 2>/dev/null; then
        log "OpenCV Python installation verified"
    else
        log_error "OpenCV Python installation failed"
        return 1
    fi
}

# Main installation function
main() {
    log "Starting OpenCV installation for Jetson..."
    
    check_root
    check_space
    
    # Install dependencies
    install_dependencies
    
    # Install OpenCV
    install_opencv_apt
    
    # Verify installation
    verify_opencv
    
    log "OpenCV installation completed successfully!"
    log "You can now use OpenCV in your Python projects"
}

# Run main function
main "$@"
