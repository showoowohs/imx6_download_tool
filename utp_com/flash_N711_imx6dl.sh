#!/bin/bash
# for imx6dl android 7.1.1

check_parameter(){
  #echo "call check_parameter()"
  if [[ $input_num -gt 3 ]];
  then
	  echo "comman error! please use ./flash_L511.sh help"
	  exit 1
  fi

  if [ "x$parameter1" = "xboot" -o "x$parameter1" = "xbootimage" ]; then
	  CMD="boot"
  elif [ "x$parameter1" = "xsystem" -o "x$parameter1" = "xsystemimage" ]; then
	  CMD="system"
  elif [ "x$parameter1" = "xuboot" -o "x$parameter1" = "xbootloader" ]; then
	  CMD="uboot"
  elif [ "x$parameter1" = "xh" -o "x$parameter1" = "xhelp" ]; then
	  echo "usage: ./flash_L511.sh [boot] [system] [uboot]"
  fi
}

only_flash_boot(){
  echo "only flash boot.img"
  cd $UTP_COM_PATH
  echo "enable boot partion 1 to boot"
  ./utp_com -d $DEVICE -c "$ mmc bootpart enable 1 1 /dev/mmcblk3"

  # Sending kernel uImage
  echo "Sending kernel uImage"
  ./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/boot-imx6dl.img
  # write boot.img
  echo "write boot.img"
  ./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk3p1"

  echo "Finishing write"
  ./utp_com -d $DEVICE -c "frf"

  # Done
  echo "Done"
  ./utp_com -d $DEVICE -c "$ echo Update Complete!"
  exit 1
}

only_flash_system(){
  echo "only flash system.img"
  cd $UTP_COM_PATH
  
  echo "Formatting system partition"
  sudo ./utp_com -d $DEVICE -c "$ mkfs.ext4  -E nodiscard /dev/mmcblk3p5"

  echo "change size of tmpfs"
  sudo ./utp_com -d $DEVICE -c "$ mount -o remount,size=800M rootfs /"

  # Sending and writting system.img
  echo "Sending and writting system.img"
  sudo ./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/system.img

  echo "writting sparse system.img"
  sudo ./utp_com -d $DEVICE -c "$ simg2img \$FILE /dev/mmcblk3p5"

  echo "Finishing write"
  sudo ./utp_com -d $DEVICE -c "frf"

  # Done
  echo "Done"
  sudo ./utp_com -d $DEVICE -c "$ echo Update Complete!"
  exit 1
}

only_flash_uboot(){

  echo "only flash uboot.img"
  cd $UTP_COM_PATH

  echo "clear u-boot arg"
  ./utp_com -d $DEVICE -c "$ dd if=/dev/zero of=/dev/mmcblk3 bs=1k seek=768 conv=fsync count=8"

  echo "access boot partition 1"
  ./utp_com -d $DEVICE -c "$ echo 0 > /sys/block/mmcblk3boot0/force_ro"

  # Sending U-Boot
  echo "Sending U-Boot"
  ./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/u-boot-imx6dl.imx
  # write U-Boot to sd card
  echo "write U-Boot to sd card"
  ./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk3boot0 bs=512 seek=2"

  # Done
  echo "Done"
  ./utp_com -d $DEVICE -c "$ echo Update Complete!"
  exit 1
}

input_num=$#
parameter1=$1
CMD=
DEVICE=

check_parameter

IMX_USB_PATH=`pwd`/../imx_usb_loader
UTP_COM_PATH=`pwd`/../utp_com/

FLASH_IMAGE_DIR=`pwd`/../images/files/android
MKSDCARD_DIR=`pwd`/../images

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
	#DEVICE=`ls -l /dev/sd* | grep "8,\s*32" | sed "s/^.*\/d/\/d/"` 
	DEVICE=`lsblk | grep "1M  1 disk" | sed "s/ .*$//" | sed "s/^/\/dev\//"`


	if [ -n "$DEVICE" ]; then
		echo "found device, you device is \"$DEVICE\""
		break
	else
		echo "your device is \"$DEVICE\", retry $i"
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

lsusb | grep "15a2\:0061" && PID=1

if [ ! "x$PID" = "x" ]; then
  exit
fi

if [ "x$CMD" = "xboot" ]; then
	only_flash_boot
elif [ "x$CMD" = "xsystem" ]; then
	only_flash_system
elif [ "x$CMD" = "xuboot" ]; then
	only_flash_uboot
fi


# Flash erase
cd $UTP_COM_PATH
echo "Sending partition shell"
./utp_com -d $DEVICE -c "send" -f ${MKSDCARD_DIR}/mksdcard-android.sh.tar

sleep 1

echo "Partitioning..."
./utp_com -d $DEVICE -c "$ tar xf \$FILE "

echo "Partitioning..."
./utp_com -d $DEVICE -c "$ sh mksdcard-android.sh /dev/mmcblk3"

#sleep 1

echo "clear u-boot arg"
./utp_com -d $DEVICE -c "$ dd if=/dev/zero of=/dev/mmcblk3 bs=1k seek=768 conv=fsync count=8"

echo "access boot partition 1"
./utp_com -d $DEVICE -c "$ echo 0 > /sys/block/mmcblk3boot0/force_ro"

# Sending U-Boot
echo "Sending U-Boot"
./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/u-boot-imx6dl.imx
# write U-Boot to sd card
echo "write U-Boot to sd card"
./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk3boot0 bs=512 seek=2"

echo "re-enable read-only access"
./utp_com -d $DEVICE -c "$ echo 1 > /sys/block/mmcblk3boot0/force_ro"

echo "enable boot partion 1 to boot"
./utp_com -d $DEVICE -c "$ mmc bootpart enable 1 1 /dev/mmcblk3"

echo "Formatting sd partition"
./utp_com -d $DEVICE -c "$ ls -l /dev/mmc* "

# Sending kernel uImage
echo "Sending kernel uImage"
./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/boot-imx6dl.img
# write boot.img
echo "write boot.img"
./utp_com -d $DEVICE -c "$ dd if=\$FILE of=/dev/mmcblk3p1"

echo "Formatting system partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4  -E nodiscard /dev/mmcblk3p5"

echo "Formatting cache partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4  -E nodiscard /dev/mmcblk3p6"

echo "Formatting device partition"
./utp_com -d $DEVICE -c "$ mkfs.ext4  -E nodiscard /dev/mmcblk3p7"

echo "change size of tmpfs"
./utp_com -d $DEVICE -c "$ mount -o remount,size=800M rootfs /"

# Sending and writting system.img
echo "Sending and writting system.img"
./utp_com -d $DEVICE -c "send" -f ${FLASH_IMAGE_DIR}/system.img

echo "writting sparse system.img"
./utp_com -d $DEVICE -c "$ simg2img \$FILE /dev/mmcblk3p5"

# Sending and writting recovery.img
echo "Sending and writting recovery.img"
./utp_com -d $DEVICE -c "pipe dd of=/dev/mmcblk3p2 bs=512" -f ${FLASH_IMAGE_DIR}/recovery-imx6dl.img

echo "Sync file system"
./utp_com -d $DEVICE -c "$ sync"

echo "Finishing rootfs write"
./utp_com -d $DEVICE -c "frf"

# Done
echo "Done"
./utp_com -d $DEVICE -c "$ echo Update Complete!"
