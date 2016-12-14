#!/bin/bash

DEVICE=

IMX_USB_PATH=/home/benson/imx6_download_tool/imx_usb_loader
UTP_COM_PATH=/home/benson/imx6_download_tool/utp_com/

FLASH_IMAGE_DIR=/home/benson/imx6_download_tool/images/files/android
MKSDCARD_DIR=/home/benson/imx6_download_tool/images

# Flash flashing os
echo "Loading U-boot and Kernel."
cd $IMX_USB_PATH
IMX_USB_PRINT=`./imx_usb 2>&1`

if `echo "$IMX_USB_PRINT" | grep -q "Could not open device"`; then
	echo "imx_usb returned error: Could not open device"
	exit 1
fi

if `echo "$IMX_USB_PRINT" | grep -q "err=-"`; then
	echo "imx_usb returned error:"
	echo $IMX_USB_PRINT
	exit 1
fi

echo "Loading Initramfs."

# Find the correct device
for i in {1..30}
do
	#DEVICE=/dev/sdc
	DEVICE=`ls -l /dev/sd* | grep "8,\s*32" | sed "s/^.*\/d/\/d/"` 

	if [ -n "$DEVICE" ]; then
		break
	fi

	sleep 1
done

if [ "x$DEVICE" = "x" ]; then
	echo "Device $DEVICE not found" 1>&2
	exit 1
elif [ ! -e $DEVICE ]; then
	echo "Device $DEVICE not found" 1>&2
	exit 1
fi

# Flash erase
cd $UTP_COM_PATH
echo "clean up u-boot parameter"
# clean up u-boot parameter
./utp_com -d $DEVICE -c "$ dd if=/dev/zero of=/dev/mmcblk0 bs=512 seek=1536 count=16"
echo "access boot partition 1"
# access boot partition 1
./utp_com -d $DEVICE -c "$ echo 1 > /sys/devices/platform/sdhci-esdhc-imx.3/mmc_host/mmc0/mmc0:0001/boot_config"

# Sending U-Boot
echo "Sending U-Boot"
./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/u-boot-6q.bin
# write U-Boot to sd card
echo "write U-Boot to sd card"
./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk0 bs=512 seek=2 skip=2"
# access user partition and enable boot partion 1 to boot
echo "access user partition and enable boot partion 1 to boot"
./utp_com -d $DEVICE -c "$ echo 8 > /sys/devices/platform/sdhci-esdhc-imx.3/mmc_host/mmc0/mmc0:0001/boot_config"

# Sending partition shell
echo "Sending partition shell"
./utp_com -d $DEVICE -c "send" -f ${MKSDCARD_DIR}/mksdcard-android.sh.tar
# Partitioning...
echo "Partitioning..."
./utp_com -d $DEVICE -c "$ tar xf \$FILE "
./utp_com -d $DEVICE -c "$ sh mksdcard-android.sh /dev/mmcblk0"

# Formatting sd partition
echo "Formatting sd partition"
./utp_com -d $DEVICE -c "$ ls -l /dev/mmc* "

# Sending kernel uImage
echo "Sending kernel uImage"
./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/boot.img
# write boot.img
echo "write boot.img"
./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk0p1"
# flush the memory.
echo "flush the memory."
./utp_com -d $DEVICE -c "frf"

# Formatting data partition
echo "Formatting data partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4 -b 4096 -m 0 /dev/mmcblk0p4"
# Sending data partition shell
echo "Formatting data partition"
./utp_com -d $DEVICE -c "send" -f ${MKSDCARD_DIR}/mk-encryptable-data-android.sh.tar
# Extracting data partition shell
echo "Extracting data partition shell"
./utp_com -d $DEVICE -c "$ tar xf \$FILE "
# Making data encryptable
echo "Making data encryptable"
./utp_com -d $DEVICE -c "$ sh mk-encryptable-data-android.sh /dev/mmcblk0 /dev/mmcblk0p4"
# Formatting system partition
echo "Formatting system partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4 /dev/mmcblk0p5"
# Formatting cache partition
echo "Formatting system partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4 /dev/mmcblk0p6"
# flush the memory.
echo "flush the memory."
./utp_com -d $DEVICE -c "frf"
# Formatting device partition
echo "Formatting device partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4 /dev/mmcblk0p7"

# Sending and writting system.img
echo "Sending and writting system.img"
./utp_com -d $DEVICE -c "pipe dd of=/dev/mmcblk0p5 bs=512" -f ${FLASH_IMAGE_DIR}/system.img
# flush the memory.
echo "flush the memory."
./utp_com -d $DEVICE -c "frf"

# Sending and writting recovery.img
echo "Sending and writting recovery.img"
./utp_com -d $DEVICE -c "pipe dd of=/dev/mmcblk0p2 bs=512" -f ${FLASH_IMAGE_DIR}/recovery.img

sleep 1
# Finishing rootfs write
echo "Finishing rootfs write"
./utp_com -d $DEVICE -c "frf"

# Done
echo "Done"
./utp_com -d $DEVICE -c "$ echo Update Complete!"
