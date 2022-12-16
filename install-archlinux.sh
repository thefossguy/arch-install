#!/usr/bin/env bash

#set -x


################################################################################
# PRE-INSTALLATION
################################################################################

# check for internet connectivity
ping -c 1 google.com >/dev/null 2>&1
if [[ ! $? -eq 0 ]]; then
    echo "No internet access :("
    exit 1
fi

# check if the user is root
if [[ $EUID -ne 0 ]]; then
    echo "This script needs to be run as the root user :("
    exit 1
fi

# detect if Arch Linux booted into Legacy BIOS or UEFI
if [[ ! "$(ls -A /sys/firmware/efi/efivars)" ]]; then
    echo "This script was tailored for a system with UEFI."
    echo "Please modify this script manually :("
    exit 1
fi


################################################################################
# SELECT THE FASTEST "HTTPS" MIRRORS
################################################################################

pacman -Sy --noconfirm reflector
MIRRORLIST_FILE="/etc/pacman.d/mirrorlist"

# check if reflector is already running
pgrep reflector >/dev/null
if [[ $? -eq 0 ]]; then
    IS_REFLECTOR_RUNNING=y
else
    IS_REFLECTOR_RUNNING=n
fi

# remove $MIRRORLIST_FILE if file modification time is more than 10 days
if [[ ! $(find "$MIRRORLIST_FILE" -mtime +10) && $IS_REFLECTOR_RUNNING == "n" ]]; then
    rm -f "$MIRRORLIST_FILE"
fi

# pacman config
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 10/" /etc/pacman.conf || echo "ParallelDownloads = 10" | tee -a /etc/pacman.conf

# start finding the best mirrors in the background
if [[ ! -f "$MIRRORLIST_FILE" && $IS_REFLECTOR_RUNNING == "n" ]]; then
    reflector \
        --connection-timeout 2 \
        --latest 100 \
        --sort rate \
        --fastest 10 \
        --protocol https \
        --save /etc/pacman.d/mirrorlist >/dev/null 2>&1 &
fi

################################################################################
# SET THINGS UP FOR INSTALLATION
################################################################################

# set some global variables
FONT_BOLD=$(tput bold)
FONT_NORM=$(tput sgr0)
YES_NO_OPTION="$FONT_BOLD(y/n)$FONT_NORM"

# update system clock
timedatectl set-ntp true


################################################################################
# CHOOSE A DRIVE ON WHICH ARCH LINUX WILL BE INSTALLED
################################################################################

# choose the drive to install Arch Linux on
OS_DRIVE=empty
CORRECTLY_CHOSEN=n

if [[ $(grep 'AuthenticAMD' /proc/cpuinfo) ]]; then
    CPU_VENDOR_NAME="amd"
elif [[ $(grep 'GenuineIntel' /proc/cpuinfo) ]]; then
    CPU_VENDOR_NAME="intel"
else
    CPU_VENDOR_NAME="nanyabusiness"
fi

while [[ $CORRECTLY_CHOSEN == "n" || $CORRECTLY_CHOSEN == "N" ]]; do
    tput -x clear
    fdisk -l

    echo -e "\n\nPlease input the full path of the storage device onto which Arch Linux should be installed: (eg: $FONT_BOLD/dev/sda$FONT_NORM)"
    read OS_DRIVE

    tput -x clear
    fdisk -l "$OS_DRIVE"

    echo -e "\n\nIs this the drive you want to install Arch Linux on? $YES_NO_OPTION"
    read CORRECTLY_CHOSEN
done


################################################################################
# FORMAT THE DRIVE ON WHICH ARCH LINUX WILL BE INSTALLED
################################################################################

# partition the drive
FORMAT_YES=no
SEPARATE_HOME_ROOT=no
TOTAL_DEV_SIZE_IN_BYTES=$(blockdev --getsize64 ${OS_DRIVE})

UEFI_PART_SIZE=513MiB
ROOT_PART_SIZE=20GiB

tput -x clear

echo "Do you want a separate \`home\` and \`root\` partition? $YES_NO_OPTION"
read SEPARATE_HOME_ROOT

if [[ $SEPARATE_HOME_ROOT == "Y" || $SEPARATE_HOME_ROOT == "y" ]]; then
    echo -e "\n\n\n\nYou chose that you want separate home and root partitions."
    echo "You will$FONT_BOLD not$FONT_NORM be asked for the Home partition's size. It will occupy the remaining space.\n"
    echo "Please enter the size of root partition in GiB (without the unit)."
    echo -e "10% or 12GB (whichever is greater) of the total drive space is usually a good idea.\n"
    read ROOT_PART_SIZE

    ROOT_PART_SIZE="$ROOT_PART_SIZE""GiB"
fi


################################################################################
# CREATE PARTITIONS
################################################################################

# create the disk partitions
tput -x clear

echo -e "Your drive will be split into 3 partitions:\n\n"
echo -e " mount point | filesystem |  size  "
echo -e "-------------|------------|----------"
echo -e " /boot/      | EFI        | 512Mib "
echo -e " /           | ext4       | $ROOT_PART_SIZE"
echo -e " /home       | ext4       | <remaining space>"

echo -e "\n\nDoes the above look good to you? $YES_NO_OPTION\n"
read FORMAT_YES

if [[ $FORMAT_YES == "y" || $FORMAT_YES == "Y" ]]; then
    parted -s "$OS_DRIVE" mklabel gpt
    parted -s "$OS_DRIVE" mkpart primary fat32 1 513MiB
    parted -s "$OS_DRIVE" mkpart logical ext4 514MiB $ROOT_PART_SIZE
    parted -s "$OS_DRIVE" mkpart logical ext4 $ROOT_PART_SIZE 100%
    parted -s "$OS_DRIVE" set 1 boot on
else
    exit 1
fi


################################################################################
# MOUNT PARTITIONS
################################################################################

# check what kind of storage device $OS_DRIVE is
if [[ "$OS_DRIVE" =~ "sd" || "$OS_DRIVE" =~ "vd" ]]; then
    UEFI_PARTITION="$OS_DRIVE""1"
    ROOT_PARTITION="$OS_DRIVE""2"
    HOME_PARTITION="$OS_DRIVE""3"
elif [[ "$OS_DRIVE" =~ "nvme" ]]; then
    UEFI_PARTITION="$OS_DRIVE""p1"
    ROOT_PARTITION="$OS_DRIVE""p2"
    HOME_PARTITION="$OS_DRIVE""p3"
fi

# format partitions
mkfs.fat -F32 "$UEFI_PARTITION"
mkfs.ext4 -F "$HOME_PARTITION"
mkfs.ext4 -F "$ROOT_PARTITION"

# mount the partitions
mount ${ROOT_PARTITION} /mnt
mount --mkdir ${UEFI_PARTITION} /mnt/boot
mount --mkdir ${HOME_PARTITION} /mnt/home


################################################################################
# INITIATE PACKAGE INSTALLATION
################################################################################

# check and copy mirrorlist
while [[ ! -f "$MIRRORLIST_FILE" ]]; do
    tput -x clear
    echo "$(date +'%Y/%m/%d %H:%M:%S') => Waiting for the mirrorlist to be generated. Please be patient."
    echo "Go touch grass for a while ;)"
    sleep 10
done
mkdir -p /mnt/etc/pacman.d/
cp ${MIRRORLIST_FILE} /mnt"$MIRRORLIST_FILE"

# update pacman db
pacman --sync --refresh --refresh

# install packages
bash scripts/install-packages.sh "$CPU_VENDOR_NAME"

# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# chroot setup
mkdir -p /mnt/chroot-scripts
cp scripts/chroot-setup.sh /mnt/chroot-scripts/
arch-chroot /mnt bash /chroot-scripts/chroot-setup.sh "$CPU_VENDOR_NAME" "$ROOT_PARTITION"
rm -rf /mnt/chroot-scripts
if [[ $? -ne 0 ]]; then
    exit 1
fi

# copy the setup script that can only be done after pratham logs in
cp scripts/pratham-setup.sh /mnt/home/pratham/pratham-setup.sh
arch-chroot /mnt chown -v pratham:pratham /home/pratham/pratham-setup.sh

# enable auto-login if Arch Linux is installed inside a VM
#if [[ $(dmidecode -s system-manufacturer) == "QEMU" ]]; then
#cat <<EOF > /mnt/etc/sddm.conf.d/kde_settings.conf
#[Autologin]
#Relogin=false
#Session=plasmawayland
#User=pratham
#
#[General]
#HaltCommand=/usr/bin/systemctl poweroff
#RebootCommand=/usr/bin/systemctl reboot
#
#[Theme]
#Current=
#
#[Users]
#MaximumUid=60513
#MinimumUid=1000
#EOF
#fi


################################################################################
# POST-INSTALL PROCEDURE
################################################################################

# unmount filesystems
umount -R /mnt
