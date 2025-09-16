#!/bin/bash

# How to use an sd card on the Jetson Xavier with Seeed A203 carrier board:
#
# 1. Run this script to place the device tree overlay
# 2. Mount the device and add it to /etc/fstab by running this shell script:
#        $ mount_device.sh sd
# 3. That's it. The system will now mount the SD card during boot. Hotplugging is not avaiable.

FLASH_LOG_FILE=/home/singularity/sources/flash/flash_log.txt
date >> $FLASH_LOG_FILE
echo "sd_mount_part1.sh started..." >> $FLASH_LOG_FILE

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

date >> $FLASH_LOG_FILE
echo "sd_mount_part1.sh finished." >> $FLASH_LOG_FILE
