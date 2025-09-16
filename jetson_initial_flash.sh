#! /bin/bash

FLASH_LOG_FILE=/home/singularity/sources/flash/flash_log.txt
date >> $FLASH_LOG_FILE
echo "jetson_initial_flash.sh started..." >> $FLASH_LOG_FILE

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

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

CMAKE_DIR="/opt/cmake-3.25.1"

# only install cmake if not already installed
if [ -d "$CMAKE_DIR" ]; then
    echo "CMake 3.25.1 is already installed at $CMAKE_DIR. Skipping installation."
else
    cd ~
    wget https://github.com/Kitware/CMake/releases/download/v3.25.1/cmake-3.25.1-linux-aarch64.tar.gz
    tar -zxvf cmake-3.25.1-linux-aarch64.tar.gz
    sudo mv cmake-3.25.1-linux-aarch64 /opt/cmake-3.25.1
    rm cmake-3.25.1-linux-aarch64.tar.gz
    echo 'export PATH=/opt/cmake-3.25.1/bin:$PATH' >> /home/singularity/.bashrc
fi

sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
# sudo apt-get install -y build-essential software-properties-common gcc-10 g++-10 libudev-dev libblas-dev liblapack-dev liblapacke-dev tmux v4l-utils python3-venv python3-pip curl

# List of packages to install
packages=(
  build-essential
  software-properties-common
  gcc-10
  g++-10
  libudev-dev
  libblas-dev
  liblapack-dev
  liblapacke-dev
  tmux
  v4l-utils
  python3-venv
  python3-pip
  curl
  proxychains
  dnsutils
  zstd
  wmctrl
  sshpass
  nlohmann-json3-dev
)

sudo apt-get install -y "${packages[@]}"

# Geographic tools removed - not needed for basic setup

echo "Verifying installed packages..."
missing=()
AUTO_RESET_FLAG=true

for pkg in "${packages[@]}"; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "✅ $pkg is installed."
  else
    echo "❌ $pkg is NOT installed."
    missing+=("$pkg")
    AUTO_RESET_FLAG=false
  fi
done

if [ ${#missing[@]} -ne 0 ]; then
  echo
  echo "The following packages failed to install:"
  for pkg in "${missing[@]}"; do
    echo "  - $pkg"
  done
  exit 1
else
  echo
  echo "All packages installed successfully."
fi

sudo jetson_clocks
sudo nvpmodel -m 8

ROOT_DEVICE=$(df --output=source / | tail -n 1)

create_service() {

    # create service to run OpenCV after install here...

    SERVICE_NAME="temp.service"
    SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
    SCRIPT_PATH="/home/singularity/sources/flash/jetson_install_opencv.sh"

    # Check if the script to run exists
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: $SCRIPT_PATH does not exist."
        exit 1
    fi

# Create the systemd service file
sudo bash -c "cat > $SERVICE_PATH" <<EOL
[Unit]
Description=Install OpenCV
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
User=root
Group=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    echo "Service file created at $SERVICE_PATH"

    # Reload systemd to recognize the new service
    sudo systemctl daemon-reload

    # Enable the service to start on boot
    sudo systemctl enable "$SERVICE_NAME"

    # Start the service now
    sudo systemctl start "$SERVICE_NAME"

    echo "Service '$SERVICE_NAME' has been created, enabled, and started."
}

# setup sd card interface
if [ ! -d "$HOME/sources/seeed-linux-dtoverlays" ]; then
    cd ~/sources
    git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays.git
    cd seeed-linux-dtoverlays
    sed -i '17s#JETSON_COMPATIBLE#\"nvidia,p3509-0000+p3668-0001", "nvidia,jetson-xavier-nx", "nvidia,tegra194"#' overlays/jetsonnano/jetson-sdmmc-overlay.dts
    make overlays/jetsonnano/jetson-sdmmc-overlay.dtbo

    DTBO_FILE="/boot/jetson-sdmmc-overlay.dtbo"

    if [ -f "$DTBO_FILE" ]; then
        sudo rm $DTBO_FILE
    fi

    sudo cp overlays/jetsonnano/jetson-sdmmc-overlay.dtbo /boot/
    echo "Device tree overlay applied. Please reboot the system to enable the SD card interface."
    sudo /opt/nvidia/jetson-io/config-by-hardware.py -l
    sudo /opt/nvidia/jetson-io/config-by-hardware.py -n "reComputer sdmmc"
fi


# only run the following script if default emmc is used
if [[ "$ROOT_DEVICE" == "/dev/mmcblk0p1" ]]; then

    echo "Creating partion on /dev/nvme0n1p1."
    sudo parted /dev/nvme0n1 --script mkpart primary ext4 1MiB 100%
    sudo mkfs.ext4 -F /dev/nvme0n1p1

    # begin rootfs transfer from emmc to SSD
    NVME_DRIVE="/dev/nvme0n1p1"

    NEW_EXTLINUX=false

    if [ -z "$NVME_DRIVE" ]
    then
        echo "SSD Storage Name is Empty!!"
        exit
    fi

    if [ ! -e "$NVME_DRIVE" ]; then
        echo "$NVME_DRIVE not exists!!"
        exit
    fi

    if [ "$(df | grep $NVME_DRIVE | wc -l)" != "0" ]
    then
        echo "SSD Storage has mounted. Please unmount it!!"
        exit
    fi

    # Mount the SSD as /mnt
    sudo mount "$NVME_DRIVE" /mnt

    # uncomment the next line if you want to automatically start the opencv install when the jetson boots back up
    # create_service

    date >> $FLASH_LOG_FILE
    echo "starting filesystem transfer..." >> $FLASH_LOG_FILE
    # Copy over the rootfs from the EMMC flash to the SSD
    sudo rsync -axHAWX --numeric-ids --info=progress2 --exclude={"/dev/","/proc/","/sys/","/tmp/","/run/","/mnt/","/media/*","/lost+found"} / /mnt
    # We want to keep the SSD mounted for further operations
    # So we do not unmount the SSD
    sync
    echo 'The rootfs have copied to SSD.'

    # Change the root parameter in extlinux.conf file
    echo -n "Before extlinux.conf: " 
    cat /mnt/boot/extlinux/extlinux.conf | grep "root="
    ROOT_DRIVE=$(df '/' | tail -1 | awk '{ printf "%s", $1 }')
    echo $ROOT_DRIVE > .root_drive_path.txt
    sed -i 's/\//\\\//g' .root_drive_path.txt
    echo $NVME_DRIVE > .nvme_drive_path.txt
    sed -i 's/\//\\\//g' .nvme_drive_path.txt

    if [ $NEW_EXTLINUX == true ]; then 
        sudo sed -i 's/root='$(cat .root_drive_path.txt)'/root='$(cat .nvme_drive_path.txt)'/g' /mnt/boot/extlinux/extlinux.conf
    else
        sudo sed -i 's/root='$(cat .root_drive_path.txt)'/root='$(cat .nvme_drive_path.txt)'/g' /boot/extlinux/extlinux.conf
        sudo cp /boot/extlinux/extlinux.conf /mnt/boot/extlinux/extlinux.conf
    fi

    rm .nvme_drive_path.txt .root_drive_path.txt
    echo -n "After extlinux.conf:  " 
    cat /mnt/boot/extlinux/extlinux.conf | grep "root="
    echo 'extlinux.conf file updated.'

    echo 'Reboot for changes to take effect.'

    # Write to log file
    date >> $FLASH_LOG_FILE
    echo "File System Transfered..." >> $FLASH_LOG_FILE

    if [ $AUTO_RESET_FLAG == true ]; then
        sudo reboot now
    else
        echo Not all packages were installed. Manually reset to boot from SSD.
    fi
fi

if [[ "$ROOT_DEVICE" == "/dev/nvme0n1p1" ]]; then
    echo "SSD already configured."

    # write to log file
    date >> $FLASH_LOG_FILE
    echo "jetson_initial_flash.sh finished and file system was already transfered so it was not attempted again." >> $FLASH_LOG_FILE

fi
