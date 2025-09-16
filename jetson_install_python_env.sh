#!/bin/bash
REPO_BRANCH="main"
# Grab the FSW Repo and install it.

#set -e
RESET='\033[0m'
COLOR='\033[1;32m'

sudo chown -R $USER:$USER /home/singularity/sources/

FLASH_LOG_FILE=/home/singularity/sources/flash/flash_log.txt
date >> $FLASH_LOG_FILE
echo "jetson_install_fsw.sh started..." >> $FLASH_LOG_FILE

function msg {
  echo -e "${COLOR}$(date): $1${RESET}"
}

function fail {
  msg "Error : $?"
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

function get_numpy_version() {
    local requirements_file="$1"  # First argument: path to requirements file

    # Ensure file exists
    if [ ! -f "$requirements_file" ]; then
        echo -e "\033[1;31mError: File not found: $requirements_file\033[0m"
        exit 1
    fi

    # Count occurrences of "numpy=="
    local numpy_count
    numpy_count=$(grep -c '^numpy==' "$requirements_file")

    # Ensure only one occurrence exists
    if [ "$numpy_count" -eq 1 ]; then
        # Extract the line, remove everything after #
        local numpy_version
        numpy_version=$(grep '^numpy==' "$requirements_file" | sed 's/#.*//g' | tr -d '[:space:]')

        echo "$numpy_version"
    elif [ "$numpy_count" -gt 1 ]; then
        echo -e "\033[1;31mError: Multiple numpy versions found in $requirements_file.\033[0m"
        grep '^numpy==' "$requirements_file"
        exit 1
    else
        echo -e "\033[1;31mError: No numpy version found in $requirements_file.\033[0m"
        exit 1
    fi
}

# Safety Check
if ! is_jetson; then
  echo "This script can only run on a jetson! Exiting!"
  exit 1
fi

resources/mount_device.sh sd
sd_status=$?

resources/mount_device.sh emmc
sd_status=$?

sudo usermod -a -G dialout $USER

# Download FSW and Run Startup.sh (take reqs.txt out of pipeline)
cd /home/singularity/sources || fail
git clone --recurse-submodules https://git.singularityus.com/revere/fsw.git || fail
cd fsw || fail

./shell/make_udev.sh

# Check if REPO_BRANCH is not "main"
if [ "$REPO_BRANCH" != "main" ]; then
  echo -e "\033[1;33mWarning: REPO_BRANCH=$REPO_BRANCH, which is NOT MAIN BRANCH! THIS IS ONLY ALLOWED IN DEVELOPMENT OF THIS SCRIPT!\033[0m"

  # Ask for user confirmation
  read -p "Would you like to continue? (y/n): " choice
  case "$choice" in 
    y|Y ) 
      msg "Continuing with branch: $REPO_BRANCH..."
      git checkout $REPO_BRANCH || fail
      ;;
    n|N ) 
      msg "Exiting script."
      exit 1
      ;;
    * ) 
      msg "Invalid choice. Exiting."
      exit 1
      ;;
  esac
fi

# install elodin-db
if ! command -v elodin-db >/dev/null 2>&1; then
    echo "elodin-db not found, installing..."
    sudo apt-get install curl
    curl -LsSf https://storage.googleapis.com/elodin-releases/install-db.sh | sh
else
    echo "elodin-db is already installed."
fi

# Once we are sure the branch is correct...
# Source startup.sh, which will install the venv into sources/fsw/venv using the chosen python configuration 
chmod +x startup.sh || fail
source ./startup.sh || fail
echo "Placing Sourcing Startup Command in the bashrc for convienience. Please ammend afterwards, if appropriate for your development environment." || fail
# Simply put the startup.sh into bashrc so that everytime we startup a terminal we are ready to go
echo "source ~/sources/fsw/startup.sh" >> ~/.bashrc || fail
# Need to extract the line with numpy from requirements.txt in fsw (boostrapping this build off it), this is needed before the OpenCV installation  
numpy_version=$(get_numpy_version ~/sources/flash/base_requirements.txt) || fail 
pip install "$numpy_version" || fail

date >> $FLASH_LOG_FILE
echo "jetson_install_fsw.sh finished." >> $FLASH_LOG_FILE


