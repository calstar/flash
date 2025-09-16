#! /bin/bash

# Jetson Python Requirements Installation (without TensorFlow GPU)
# Note: TensorFlow GPU dependencies removed - basic Python packages only

FLASH_LOG_FILE=/home/singularity/sources/flash/flash_log.txt
date >> $FLASH_LOG_FILE
echo "jetson_install_pyreqs_base.sh started..." >> $FLASH_LOG_FILE

function fail {
  echo "Error: $?"
  exit 1
}

is_jetson() {
    local arch
    arch=$(uname -m)  # Get system architecture

    # Check if architecture is aarch64 (ARM 64-bit) and NVIDIA Jetson-specific files exist
    if [[ "$arch" == "aarch64" && -f "/proc/device-tree/model" && $(cat /proc/device-tree/model) == *"Jetson"* ]]; then
        return 0  # True (it's a Jetson)
    else
        return 1  # False (not a Jetson)
    fi
}
# Safety Check
if ! is_jetson; then
  echo "This script can only run on a jetson! Exiting!"
  exit 1
fi

# Setup Python environment and install base requirements
cd ~/sources || fail

# Activate virtual environment if it exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate || fail
    echo "Python virtual environment activated"
else
    echo "Creating Python virtual environment..."
    python3 -m venv venv || fail
    source venv/bin/activate || fail
fi

# Install base Python requirements
cd ~/sources/flash || fail
if [ -f "base_requirements.txt" ]; then
    echo "Installing base Python requirements..."
    pip install --upgrade pip || fail
    pip install -r base_requirements.txt || fail
    echo "Base Python requirements installed successfully"
else
    echo "base_requirements.txt not found, skipping Python package installation"
fi

# Install additional useful packages for Jetson development
echo "Installing additional development packages..."
pip install testresources setuptools || fail
pip install future mock protobuf pybind11 cython pkgconfig packaging || fail

# Install basic machine learning packages (without TensorFlow GPU)
echo "Installing basic ML packages..."
pip install scikit-learn || fail
pip install matplotlib || fail
pip install pandas || fail
pip install numpy || fail

# Verify installation
echo "Verifying Python package installation..."
python -c "import numpy, matplotlib, pandas, sklearn; print('Core packages installed successfully')" || fail

# End of script
echo "Successfully installed Python requirements on the NVIDIA Jetson Xavier!"

date >> $FLASH_LOG_FILE
echo "jetson_install_pyreqs_base.sh finished." >> $FLASH_LOG_FILE
