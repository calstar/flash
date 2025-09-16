#!/bin/bash

FLASH_LOG_FILE="/home/singularity/sources/flash/flash_log.txt"
FSTAB_FILE="/etc/fstab"

# mount_device_with_fstab() {
#     local DEVICE="$1"
#     local MOUNT_POINT="$2"

#     date >> "$FLASH_LOG_FILE"
#     echo "mount_device_with_fstab started for $DEVICE..." >> "$FLASH_LOG_FILE"

#     if [ ! -b "$DEVICE" ]; then
#         echo "Device $DEVICE not found. Skipping mount."
#         date >> "$FLASH_LOG_FILE"
#         echo "Device $DEVICE not found. mount_device_with_fstab finished unsuccessfully." >> "$FLASH_LOG_FILE"
#         return 1
#     fi

#     CURRENT_MOUNT_POINT=$(findmnt -nr -S "$DEVICE" -o TARGET)

#     if [ -n "$CURRENT_MOUNT_POINT" ]; then
#         echo "Device $DEVICE is currently mounted at $CURRENT_MOUNT_POINT. Unmounting..."
#         sudo umount "$DEVICE"
#         if [ $? -eq 0 ]; then
#             echo "Successfully unmounted $DEVICE."
#         else
#             echo "Error: Failed to unmount $DEVICE."
#             date >> "$FLASH_LOG_FILE"
#             echo "Error: Failed to unmount $DEVICE." >> "$FLASH_LOG_FILE"
#             echo "mount_device_with_fstab finished unsuccessfully." >> "$FLASH_LOG_FILE"
#             # Continue execution
#         fi
#     else
#         echo "Device $DEVICE is not currently mounted. Proceeding..."
#     fi

#     UUID=$(sudo blkid -s UUID -o value "$DEVICE")

#     if [ -z "$UUID" ]; then
#         echo "Error: Unable to retrieve UUID for $DEVICE."
#         date >> "$FLASH_LOG_FILE"
#         echo "Error: Unable to retrieve UUID for $DEVICE. /etc/fstab not updated." >> "$FLASH_LOG_FILE"
#         return 1
#     fi

#     if [ ! -d "$MOUNT_POINT" ]; then
#         sudo mkdir -p "$MOUNT_POINT"
#     fi

#     if grep -q "$UUID" "$FSTAB_FILE"; then
#         echo "UUID $UUID already present in $FSTAB_FILE."
#     else
#         echo "UUID=$UUID  $MOUNT_POINT  auto  defaults,nofail  0  2" | sudo tee -a "$FSTAB_FILE"
#         echo "Added UUID $UUID to $FSTAB_FILE."
#         sudo systemctl daemon-reexec
#         sudo mount -a
#         date >> "$FLASH_LOG_FILE"
#         echo "mount_device_with_fstab finished successfully for $DEVICE." >> "$FLASH_LOG_FILE"
#     fi

#     return 0
# }


mount_device_with_fstab() {

    local DEVICE="$1"
    local MOUNT_POINT="$2"

    date >> $FLASH_LOG_FILE
    echo "mount_device_with_fstab.sh started..." >> $FLASH_LOG_FILE

    # Check if the device exists
    if [ ! -b "$DEVICE" ]; then
        echo "SD card not inserted. Skipping this step. To fix this, insert sd card before boot up and then run ./deprc/mount_device_with_fstab.sh"
        
        date >> $FLASH_LOG_FILE
        echo "mount_device_with_fstab.sh finished unsuccessfully." >> $FLASH_LOG_FILE
    else

        CURRENT_MOUNT_POINT=$(findmnt -nr -S "$DEVICE" -o TARGET)

        if [ -n "$CURRENT_MOUNT_POINT" ]; then
            echo "Device $DEVICE is currently mounted at $CURRENT_MOUNT_POINT. Unmounting..."
            sudo umount "$DEVICE"
            if [ $? -eq 0 ]; then
                echo "Successfully unmounted $DEVICE from $CURRENT_MOUNT_POINT."
            else
                echo "Error: Failed to unmount $DEVICE from $CURRENT_MOUNT_POINT."
                
                # log failure to file but continue
                date >> $FLASH_LOG_FILE
                echo "Error: Failed to unmount $DEVICE from $CURRENT_MOUNT_POINT." >> $FLASH_LOG_FILE
                echo "mount_device_with_fstab.sh finished unsuccessfully." >> $FLASH_LOG_FILE

            fi
        else
            echo "Device $DEVICE is not mounted. Proceeding..."
        fi
        

        # Create the mount point directory if it doesn't exist
        if [ ! -d "$MOUNT_POINT" ]; then
            sudo mkdir -p "$MOUNT_POINT"
        fi


        # Format SD card
        if [[ $MOUNT_POINT == "/mnt/sdcard" ]]; then

            FS_TYPE=$(blkid -o value -s TYPE "$DEVICE")
            echo $FS_TYPE found on $DEVICE
            if [[ "$FS_TYPE" != "ext4" ]]; then
                echo "[INFO] $DEVICE does not have an ext4 filesystem (detected: '$FS_TYPE'). Formatting now..."
                sudo mkfs.ext4 "$DEVICE"

                # Optional: label it for stable fstab entry
                # sudo e2label "$DEVICE" sdcard
            else
                echo "[INFO] $DEVICE already has an ext4 filesystem. Skipping format."
            fi

            sudo mount -t ext4 "$DEVICE" "$MOUNT_POINT"

        fi

        # Retrieve the UUID of the device
        UUID=$(sudo blkid -s UUID -o value "$DEVICE")

        # Verify that UUID was retrieved
        if [ -z "$UUID" ]; then
            echo "Error: Unable to retrieve UUID for $DEVICE."

            # log failure to file but continue
            date >> $FLASH_LOG_FILE
            echo "Error: Unable to retrieve UUID for $DEVICE. /etc/fstab file not updated." >> $FLASH_LOG_FILE
        else

            # Check if the UUID is already present in /etc/fstab
            if grep -q "$UUID" "$FSTAB_FILE"; then
                echo "UUID $UUID is already present in $FSTAB_FILE."
            else

                # Append the new entry to /etc/fstab
                echo "UUID=$UUID  $MOUNT_POINT  auto  defaults,nofail  0  2" | sudo tee -a "$FSTAB_FILE"
                echo "Added UUID $UUID to $FSTAB_FILE."
                sudo systemctl daemon-reload 
                sudo mount -a

                # change ownership
                sudo chown -R $USER:$USER $MOUNT_POINT

                date >> $FLASH_LOG_FILE
                echo "mount_device_with_fstab.sh finished successfully." >> $FLASH_LOG_FILE
                
            fi  
        fi
    fi

}


# Exit if no argument is passed
if [[ -z "$1" ]]; then
    echo "Usage: $0 <sd|emmc>"
    exit 1
fi

device_to_mount=$1

if [[ $device_to_mount == "sd" ]]; then
    echo mounting sd
    mount_device_with_fstab /dev/mmcblk1p1 /mnt/sdcard
    emmc_status=$?
elif [[ $device_to_mount == "emmc" ]]; then
    echo mounting emmc
    mount_device_with_fstab /dev/mmcblk0p1 /mnt/emmc
    emmc_status=$?
else
    echo unknown command
fi

sudo mount -a
