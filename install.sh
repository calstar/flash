#!/bin/bash
# Cross-Platform Flash Installation System
# Supports: macOS (Homebrew), Debian/Ubuntu (apt), Windows (WSL/chocolatey)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="flash_install.log"
FLASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ -f "install_config.sh" ]]; then
    source install_config.sh
else
    # Default configuration
    PYTHON_VERSION="3.8.10"
    REPO_BRANCH="main"
    INSTALL_BASHDB=false
    INSTALL_ELODIN_EDITOR=true
    INSTALL_ELODIN_DB=true
    ENABLE_PYTHON_COMPILATION=true
    ENABLE_STARTUP_INTEGRATION=true
    ENABLE_SUDO_SETUP=true
    VERBOSE_LOGGING=false
fi

# Platform detection
detect_platform() {
    local os_name
    local arch
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_name="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check if running in WSL
        if grep -q Microsoft /proc/version 2>/dev/null; then
            os_name="wsl"
        elif command -v apt >/dev/null 2>&1; then
            # Check if it's Debian or Ubuntu
            if [[ -f /etc/debian_version ]]; then
                if grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
                    os_name="ubuntu"
                else
                    os_name="debian"
                fi
            else
                os_name="debian"
            fi
        else
            os_name="linux"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        os_name="windows"
    else
        os_name="unknown"
    fi
    
    # Detect architecture
    arch=$(uname -m)
    case $arch in
        x86_64) arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) arch="unknown" ;;
    esac
    
    echo "${os_name}_${arch}"
}

# Get numpy version from requirements file
get_numpy_version() {
    local requirements_file="$1"
    
    if [ ! -f "$requirements_file" ]; then
        log_error "File not found: $requirements_file"
        return 1
    fi
    
    local numpy_count
    numpy_count=$(grep -c '^numpy==' "$requirements_file" 2>/dev/null || echo "0")
    
    if [ "$numpy_count" -eq 1 ]; then
        grep '^numpy==' "$requirements_file" | sed 's/#.*//g' | tr -d '[:space:]'
    elif [ "$numpy_count" -gt 1 ]; then
        log_error "Multiple numpy versions found in $requirements_file"
        return 1
    else
        log_error "No numpy version found in $requirements_file"
        return 1
    fi
}

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Error handling
fail() {
    log_error "Installation failed: $1"
    exit 1
}

# Check if running as root (not recommended for most operations)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. This is not recommended for most operations."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Platform-specific package manager functions
install_package_manager() {
    local platform=$1
    
    case $platform in
        "macos"*)
            if ! command -v brew >/dev/null 2>&1; then
                log "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # Add Homebrew to PATH for Apple Silicon Macs
                if [[ $(uname -m) == "arm64" ]]; then
                    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            else
                log "Homebrew already installed"
            fi
            ;;
        "debian"*)
            if ! command -v apt >/dev/null 2>&1; then
                fail "apt package manager not found. Please install on a Debian-based system."
            fi
            log "Using apt package manager"
            ;;
        "windows"*)
            if ! command -v choco >/dev/null 2>&1; then
                log "Installing Chocolatey..."
                powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
            else
                log "Chocolatey already installed"
            fi
            ;;
        *)
            fail "Unsupported platform: $platform"
            ;;
    esac
}

# Install system packages
install_system_packages() {
    local platform=$1
    
    log "Installing system packages for $platform..."
    
    case $platform in
        "macos"*)
            # Update Homebrew
            brew update
            
            # Install core packages
            brew install cmake git python@3.9 wget curl pkg-config
            
            # Install OpenCV and related packages
            brew install opencv
            
            # Install additional development tools
            if [ "$INSTALL_BASHDB" = true ]; then
                brew install autoconf automake m4 texinfo
            fi
            
            # Install elodin dependencies
            if [ "$INSTALL_ELODIN_EDITOR" = true ] || [ "$INSTALL_ELODIN_DB" = true ]; then
                brew install rust
            fi
            
            # Install additional Python development packages
            brew install python-tk  # For matplotlib GUI support
            
            # Verify installations
            log "Verifying macOS installations..."
            python3 --version || log_warn "Python installation may have issues"
            cmake --version || log_warn "CMake installation may have issues"
            rustc --version || log_warn "Rust installation may have issues"
            
            # Check architecture
            local arch=$(uname -m)
            log "Running on macOS $(sw_vers -productVersion) ($arch)"
            
            # Add Homebrew to PATH if needed (especially for Apple Silicon)
            if [[ "$arch" == "arm64" ]]; then
                log "Apple Silicon Mac detected - ensuring Homebrew is in PATH"
                if ! echo "$PATH" | grep -q "/opt/homebrew/bin"; then
                    echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
                    echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.bash_profile
                    log "Added Homebrew to PATH in shell configuration files"
                fi
            fi
            ;;
        "debian"*|"ubuntu"*|"wsl"*)
            # Update package lists
            sudo apt update
            
            # Add universe repository for Ubuntu
            if [[ "$platform" == "ubuntu"* ]]; then
                sudo apt install -y software-properties-common
                sudo add-apt-repository universe -y
                sudo apt update
            fi
            
            # Install packages
            sudo apt install -y \
                build-essential \
                cmake \
                git \
                python3 \
                python3-pip \
                python3-venv \
                python3-dev \
                wget \
                curl \
                pkg-config \
                libopencv-dev \
                libjpeg-dev \
                libpng-dev \
                libtiff-dev \
                libavcodec-dev \
                libavformat-dev \
                libswscale-dev \
                libgtk-3-dev \
                libatlas-base-dev \
                libblas-dev \
                liblapack-dev \
                liblapacke-dev \
                libeigen3-dev \
                gfortran \
                zlib1g-dev \
                libffi-dev \
                libssl-dev \
                libsqlite3-dev \
                libreadline-dev \
                libbz2-dev \
                libncursesw5-dev \
                libgdbm-dev \
                liblzma-dev \
                tk-dev \
                uuid-dev \
                openssl \
                proxychains \
                dnsutils \
                openssh-server \
                zstd \
                wmctrl \
                sshpass \
                net-tools \
                vim \
                tmux \
                ccache \
                libcanberra-gtk* \
                libfaac-dev \
                libglew-dev \
                libhdf5-dev \
                libjpeg-turbo8-dev \
                libjpeg8-dev \
                libmp3lame-dev \
                libpostproc-dev \
                libprotobuf-dev \
                libtesseract-dev \
                protobuf-compiler \
                qt5-qmake \
                qtbase5-dev \
                qtchooser \
                qttools5-dev-tools \
                qv4l2 \
                v4l-utils \
                qtbase5-dev-tools \
                libqt5gui5t64 \
                qtbase5-private-dev \
                libboost-all-dev \
                libfftw3-dev \
                libfftw3-mpi-dev \
                libmpfr-dev \
                libopenblas-dev \
                libsuperlu-dev \
                libtbb-dev \
                checkinstall \
                pylint \
                python3-numpy \
                python3-tk \
                doxygen
            
            # Install bashdb dependencies if requested
            if [ "$INSTALL_BASHDB" = true ]; then
                sudo apt install -y autoconf automake m4 texinfo
            fi
            ;;
        "windows"*)
            choco install -y cmake git python wget curl pkgconfig
            choco install -y opencv
            ;;
    esac
}

# Compile Python from source (Linux only)
compile_python_from_source() {
    local platform=$1
    
    if [[ "$ENABLE_PYTHON_COMPILATION" != true ]]; then
        log "Skipping Python compilation (disabled in configuration)"
        return 0
    fi
    
    if [[ "$platform" != "debian"* && "$platform" != "ubuntu"* ]]; then
        log "Skipping Python compilation on $platform (only supported on Debian/Ubuntu)"
        return 0
    fi
    
    log "Compiling Python $PYTHON_VERSION from source..."
    
    local python_tgz="Python-${PYTHON_VERSION}.tgz"
    local python_url="https://www.python.org/ftp/python/${PYTHON_VERSION}/${python_tgz}"
    local python_install_path="$FLASH_DIR/resources/groundstation_python"
    
    # Create resources directory
    mkdir -p "$FLASH_DIR/resources"
    cd "$FLASH_DIR/resources"
    
    # Download and extract Python source
    log "Downloading Python ${PYTHON_VERSION} source..."
    wget -q "$python_url" || fail "Failed to download Python source"
    tar xvf "$python_tgz" || fail "Failed to extract Python source"
    
    # Detect OpenSSL directory
    local openssl_path
    openssl_path=$(openssl version -d | awk -F'"' '{print $2}') || fail "Failed to detect OpenSSL path"
    log "Detected OpenSSL path: $openssl_path"
    
    # Configure and build Python
    cd "Python-$PYTHON_VERSION" || fail "Failed to enter Python source directory"
    ./configure --prefix="$python_install_path" --enable-optimizations --with-openssl="/usr" || fail "Failed to configure Python"
    make -j$(nproc) || fail "Failed to build Python"
    make install || fail "Failed to install Python"
    
    # Cleanup
    cd ..
    rm -rf "Python-$PYTHON_VERSION"
    rm "$python_tgz"
    
    # Verify installation
    log "Verifying Python installation..."
    "$python_install_path/bin/python3.8" --version || fail "Python installation verification failed"
    "$python_install_path/bin/python3.8" -c "import ssl; print(ssl.OPENSSL_VERSION)" || fail "SSL module verification failed"
    
    log "Python ${PYTHON_VERSION} compiled successfully!"
}

# Setup Python environment
setup_python_environment() {
    local platform=$1
    local python_cmd
    
    log "Setting up Python environment..."
    
    # Determine Python command based on platform
    case $platform in
        "macos"*)
            # On macOS, ensure we're using the Homebrew Python
            if command -v python3 >/dev/null 2>&1; then
                python_cmd="python3"
            else
                log_warn "Python3 not found, trying to install via Homebrew"
                brew install python@3.9
                python_cmd="python3"
            fi
            ;;
        "debian"*|"ubuntu"*)
            python_cmd="python3"
            ;;
        "windows"*)
            python_cmd="python"
            ;;
    esac
    
    # Create virtual environment
    if [[ ! -d "venv" ]]; then
        log "Creating Python virtual environment..."
        $python_cmd -m venv venv
    fi
    
    # Activate virtual environment
    case $platform in
        "macos"*|"debian"*|"ubuntu"*)
            source venv/bin/activate
            ;;
        "windows"*)
            source venv/Scripts/activate
            ;;
    esac
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python requirements
    if [[ -f "base_requirements.txt" ]]; then
        log "Installing Python requirements from base_requirements.txt..."
        log "Installing into virtual environment: $(pwd)/venv"
        pip install -r base_requirements.txt
        
        # Install specific numpy version if specified
        local numpy_version
        if numpy_version=$(get_numpy_version "base_requirements.txt"); then
            log "Installing specific numpy version: $numpy_version"
            pip install "$numpy_version"
        fi
        
        # Verify installation
        log "Verifying Python package installation..."
        python -c "import numpy, matplotlib, pandas, cv2; print('Core packages installed successfully')" || log_warn "Some packages may not have installed correctly"
    else
        log_warn "base_requirements.txt not found, skipping Python package installation"
    fi
}

# Install elodin editor
install_elodin_editor() {
    local platform=$1
    
    if [ "$INSTALL_ELODIN_EDITOR" != true ]; then
        log "Skipping elodin editor installation (disabled)"
        return 0
    fi
    
    log "Installing elodin editor..."
    
    if command -v elodin >/dev/null 2>&1; then
        log "elodin editor already installed"
        return 0
    fi
    
    case $platform in
        "debian"*|"ubuntu"*|"wsl"*|"macos"*)
            log "Installing elodin editor via installer script..."
            curl --proto '=https' --tlsv1.2 -LsSf https://github.com/elodin-sys/elodin/releases/download/v0.14.2/elodin-installer.sh | sh
            ;;
        "windows"*)
            log_warn "elodin editor on Windows requires WSL or manual installation"
            log "Please install WSL and run this installer from within WSL, or download manually from:"
            log "https://github.com/elodin-sys/elodin/releases/download/v0.14.2/elodin-x86_64-pc-windows-msvc.zip"
            ;;
    esac
}

# Install elodin-db
install_elodin_db() {
    local platform=$1
    
    if [ "$INSTALL_ELODIN_DB" != true ]; then
        log "Skipping elodin-db installation (disabled)"
        return 0
    fi
    
    log "Installing elodin-db..."
    
    if command -v elodin-db >/dev/null 2>&1; then
        log "elodin-db already installed"
        return 0
    fi
    
    case $platform in
        "debian"*|"ubuntu"*|"wsl"*|"macos"*)
            log "Installing elodin-db via installer script..."
            curl --proto '=https' --tlsv1.2 -LsSf https://github.com/elodin-sys/elodin/releases/download/v0.14.2/elodin-db-installer.sh | sh
            ;;
        "windows"*)
            log_warn "elodin-db is not available on Windows"
            log "Please use WSL (Windows Subsystem for Linux) to run this installer"
            log "Or download manually from:"
            log "https://github.com/elodin-sys/elodin/releases/download/v0.14.2/"
            ;;
    esac
}

# Install bashdb (optional development tool)
install_bashdb() {
    local platform=$1
    
    if [ "$INSTALL_BASHDB" != true ]; then
        log "Skipping bashdb installation (disabled)"
        return 0
    fi
    
    log "Installing bashdb debugger..."
    
    if command -v bashdb >/dev/null 2>&1; then
        log "bashdb already installed"
        return 0
    fi
    
    case $platform in
        "debian"*|"ubuntu"*)
            local bash_version
            bash_version=$(bash --version | head -n1 | cut -d ' ' -f4 | cut -d '.' -f1,2)
            log "Detected Bash version: $bash_version"
            
            cd "$FLASH_DIR/resources" || fail "Failed to enter resources directory"
            git clone https://github.com/Trepan-Debuggers/bashdb.git || fail "Failed to clone bashdb"
            cd bashdb || fail "Failed to enter bashdb directory"
            git checkout "bash-$bash_version" || fail "Failed to checkout bash version"
            
            log "Building bashdb..."
            ./autogen.sh || fail "Failed to run autogen.sh"
            ./configure || fail "Failed to configure bashdb"
            make || fail "Failed to build bashdb"
            sudo make install || fail "Failed to install bashdb"
            
            # Verify installation
            bashdb --version || fail "bashdb installation verification failed"
            
            # Cleanup
            cd ..
            rm -rf bashdb
            log "bashdb installed successfully"
            ;;
        "macos"*)
            if command -v brew >/dev/null 2>&1; then
                brew install bashdb
            else
                log_warn "Homebrew not available, skipping bashdb installation"
            fi
            ;;
        "windows"*)
            log_warn "bashdb installation on Windows not implemented"
            ;;
    esac
}

# Setup startup.sh integration
setup_startup_integration() {
    local platform=$1
    
    if [[ "$ENABLE_STARTUP_INTEGRATION" != true ]]; then
        log "Skipping startup.sh integration (disabled in configuration)"
        return 0
    fi
    
    log "Setting up startup.sh integration..."
    
    # Create a basic startup.sh if it doesn't exist
    if [[ ! -f "startup.sh" ]]; then
        log "Creating basic startup.sh..."
        cat > startup.sh << 'EOF'
#!/bin/bash
# Basic startup script for flash environment

# Activate virtual environment
if [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate
    echo "Virtual environment activated"
elif [[ -f "venv/Scripts/activate" ]]; then
    source venv/Scripts/activate
    echo "Virtual environment activated"
fi

# Set environment variables
export FLASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$FLASH_DIR:$PYTHONPATH"

echo "Flash environment ready"
EOF
        chmod +x startup.sh
    fi
    
    # Add to shell configuration
    local shell_config
    case $platform in
        "macos"*|"debian"*|"ubuntu"*)
            shell_config="$HOME/.bashrc"
            ;;
        "windows"*)
            shell_config="$HOME/.bashrc"
            ;;
    esac
    
    if [[ -f "$shell_config" ]]; then
        local startup_line="source $FLASH_DIR/startup.sh"
        if ! grep -q "source $FLASH_DIR/startup.sh" "$shell_config"; then
            log "Adding startup.sh to $shell_config"
            echo "$startup_line" >> "$shell_config"
        else
            log "startup.sh already in $shell_config"
        fi
    fi
}

# Setup sudo permissions (Linux only)
setup_sudo_permissions() {
    local platform=$1
    
    if [[ "$ENABLE_SUDO_SETUP" != true ]]; then
        log "Skipping sudo permissions setup (disabled in configuration)"
        return 0
    fi
    
    if [[ "$platform" != "debian"* && "$platform" != "ubuntu"* ]]; then
        log "Skipping sudo permissions setup on $platform (Linux only)"
        return 0
    fi
    
    log "Setting up sudo permissions..."
    
    local sudoers_file="/etc/sudoers.d/$USER-modprobe-ip"
    if [[ ! -f "$sudoers_file" ]]; then
        echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/modprobe, /usr/sbin/ip" | sudo tee "$sudoers_file"
        log "Added sudo permissions for modprobe and ip"
    else
        log "Sudo permissions already configured"
    fi
}

# Install OpenCV (if not already installed via package manager)
install_opencv() {
    local platform=$1
    
    log "Checking OpenCV installation..."
    
    # Check if OpenCV is already available
    if python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" 2>/dev/null; then
        log "OpenCV already installed"
        return 0
    fi
    
    log "Installing OpenCV via pip..."
    pip install opencv-python opencv-contrib-python
    
    # Verify installation
    if python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" 2>/dev/null; then
        log "OpenCV installed successfully"
    else
        # Platform-specific troubleshooting
        case $platform in
            "macos"*)
                log_warn "OpenCV installation failed on macOS"
                log "Trying to fix with Homebrew OpenCV..."
                brew install opencv
                # Try to link OpenCV libraries
                if [[ -d "/opt/homebrew/lib/python3.9/site-packages" ]]; then
                    ln -sf /opt/homebrew/lib/python3.9/site-packages/cv2* venv/lib/python3.9/site-packages/ 2>/dev/null || true
                elif [[ -d "/usr/local/lib/python3.9/site-packages" ]]; then
                    ln -sf /usr/local/lib/python3.9/site-packages/cv2* venv/lib/python3.9/site-packages/ 2>/dev/null || true
                fi
                # Try pip install again
                pip install opencv-python opencv-contrib-python
                ;;
        esac
        
        # Final verification
        if python -c "import cv2; print(f'OpenCV version: {cv2.__version__}')" 2>/dev/null; then
            log "OpenCV installed successfully after troubleshooting"
        else
            fail "OpenCV installation failed"
        fi
    fi
}

# Main installation function
main() {
    local platform
    
    log "Starting cross-platform flash installation..."
    
    # Detect platform
    platform=$(detect_platform)
    log "Detected platform: $platform"
    
    # Platform-specific messaging
    case $platform in
        "wsl"*)
            log "Running in WSL (Windows Subsystem for Linux)"
            log "This is the recommended way to run the installer on Windows"
            ;;
        "windows"*)
            log_warn "Running on native Windows"
            log "For best compatibility, consider using WSL (Windows Subsystem for Linux)"
            log "Some features like elodin-db are not available on native Windows"
            ;;
        "macos"*)
            log "Running on macOS"
            log "Using Homebrew package manager"
            ;;
        "debian"*)
            log "Running on Debian Linux"
            log "Using apt package manager"
            ;;
        "ubuntu"*)
            log "Running on Ubuntu Linux"
            log "Using apt package manager with universe repository"
            ;;
    esac
    
    # Check if running as root
    check_root
    
    # Install package manager
    install_package_manager "$platform"
    
    # Install system packages
    install_system_packages "$platform"
    
    # Compile Python from source (Linux only)
    compile_python_from_source "$platform"
    
    # Setup Python environment
    setup_python_environment "$platform"
    
    # Install elodin editor
    install_elodin_editor "$platform"
    
    # Install elodin-db
    install_elodin_db "$platform"
    
    # Install bashdb (optional)
    install_bashdb "$platform"
    
    # Setup startup.sh integration
    setup_startup_integration "$platform"
    
    # Setup sudo permissions (Linux only)
    setup_sudo_permissions "$platform"
    
    # Install OpenCV
    install_opencv "$platform"
    
    log "Installation completed successfully!"
    log "You can now use the Python environment by activating it:"
    case $platform in
        "macos"*|"debian"*|"ubuntu"*)
            log "  source venv/bin/activate"
            log "  source startup.sh  # or restart your terminal"
            ;;
        "windows"*)
            log "  venv\\Scripts\\activate"
            log "  startup.sh  # or restart your terminal"
            ;;
    esac
    
    log "For development, you can use:"
    if [ "$INSTALL_ELODIN_EDITOR" = true ]; then
        log "  elodin  # elodin editor"
    fi
    if [ "$INSTALL_ELODIN_DB" = true ]; then
        log "  elodin-db  # database management"
    fi
    if [ "$INSTALL_BASHDB" = true ]; then
        log "  bashdb script_name.sh  # to debug bash scripts"
    fi
}

# Run main function
main "$@"
