#!/usr/bin/env bash

# $1: CPU Vendor (AMD/Intel)
# $2: Device that is mounted at "$ESP_PATH"


################################################################################
ROOT_CRONTAB="# remove cache every 2 hours and update local db
0 */2 * * * paccache -r >/dev/null 2>&1
0 * * * * pacman --sync --refresh >/dev/null 2>&1

# update the on-disk database every 6 hours
0 */6 * * * updatedb >/dev/null 2>&1

# zfs scrub
0 0 1,15 * * /usr/bin/zpool scrub
"
################################################################################

tput -x clear

################################################################################
# BASIC CHROOT SETUP
################################################################################

# exit early if mirrorlist does not exist
if [[ ! -f "/etc/pacman.d/mirrorlist" ]]; then
    echo "A mirrorlist does not exist :("
    exit 1
fi

# exit early if $1 is an unknown vendor
if [[ "$1" == "nanyabusiness" ]]; then
    echo "CPU Vendor is not AMD nor Intel. This will interfere with generating \"\$ESP_PATH\"/loader/entries/arch.conf"
    exit 1
fi

# set timezone
ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

# generate locale
echo "en_IN UTF-8" > /etc/locale.gen
locale-gen

# set the machine hostname
echo "flameboi" > /etc/hostname

# create a new initramfs just to be safe
mkinitcpio -P
echo "initramfs successfully created"


################################################################################
# BASIC CHROOT SETUP
################################################################################

# pacman config
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 6/" /etc/pacman.conf || echo "ParallelDownloads = 6" | tee -a /etc/pacman.conf
sed -i "s/#Color/Color/" /etc/pacman.conf

# update pacman db
pacman --sync --refresh --refresh --sysupgrade


################################################################################
# USER SETUP
################################################################################

# setup the user pratham
useradd -m -G adm,ftp,games,http,kvm,libvirt,log,rfkill,sys,systemd-journal,uucp,wheel -s /bin/zsh pratham
usermod --password $(echo pratham | openssl passwd -1 -stdin) pratham

# don't expire the password, for now
# https://github.com/sddm/sddm/issues/716
#passwd -e pratham

# setup the root user
usermod --password $(echo root | openssl passwd -1 -stdin) root

# setup doas for pratham
echo "permit persist keepenv pratham" | tee -a /etc/doas.conf

# setup root user's cron jobs
echo "${ROOT_CRONTAB}" | crontab -

# copy dotfiles
sudo -u pratham /chroot-scripts/doas-pratham.sh


################################################################################
# BSPWM SETUP
################################################################################

cat <<EOF > /usr/share/xsessions/bspwm.desktop
[Desktop Entry]
Name=bspwm
Comment=Binary space partitioning window manager
Exec=/home/pratham/.xinitrc
Type=Application
EOF


################################################################################
# SSH SETUP
################################################################################

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/g' /etc/ssh/sshd_config
sed -i 's/#X11Forwarding no/X11Forwarding no/g' /etc/ssh/sshd_config


################################################################################
# LIBVIRT/KVM/QEMU SETUP
################################################################################

sed -i 's/FirewallBackend=nftables/FirewallBackend=iptables/g' /etc/firewalld/firewalld.conf
sed -i 's@#uri_default = "qemu:///system"@uri_default = "qemu:///system"@g' /etc/libvirt/libvirt.conf
sed -i 's/#user = "libvirt-qemu"/user = "pratham"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "pratham"/g' /etc/libvirt/qemu.conf


################################################################################
# LOCATEDB SETUP
################################################################################

sed -i 's@PRUNEPATHS = "@&/heathen_disk/personal/media/camera_roll @g' /etc/updatedb.conf


################################################################################
# NVIDIA SETUP
################################################################################

systemctl unmask nvidia-suspend nvidia-hibernate nvidia-resume
systemctl enable nvidia-suspend nvidia-hibernate nvidia-resume

mkdir -p /etc/pacman.d/hooks
cat <<EOF > /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-lts
Target=linux-lts
Target=linux-lts-headers

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF


################################################################################
# BOOT MANAGER
################################################################################

ESP_PATH="/boot"

# install a boot manager
bootctl --esp-path="$ESP_PATH" --path="$ESP_PATH" install

# configure systemd-boot
mkdir -p "$ESP_PATH"/loader/entries

cat <<EOF > "$ESP_PATH"/loader/loader.conf
default          arch-01-lts.conf
timeout          10
console-mode     auto
editor           no
auto-firmware    no
EOF

cat <<EOF > "$ESP_PATH"/loader/entries/arch-01-lts.conf
title   Arch Linux LTS kernel
linux   /vmlinuz-linux-lts
initrd  /$1-ucode.img
initrd  /initramfs-linux-lts.img
options root=UUID=$(blkid $2 -s UUID -o value) rw mem_sleep_default=deep ignore_loglevel audit=0 nvidia_drm.modeset=1
EOF

cat <<EOF > "$ESP_PATH"/loader/entries/arch-02-non-lts.conf
title   Arch Linux latest kernel
linux   /vmlinuz-linux
initrd  /$1-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$(blkid $2 -s UUID -o value) rw mem_sleep_default=deep ignore_loglevel audit=0 nvidia_drm.modeset=1
EOF

# option "ignore_loglevel" displays all kernel messages, very useful in fallback
cat <<EOF > "$ESP_PATH"/loader/entries/arch-03-lts-fallback.conf
title   Arch Linux LTS kernel (FALLBACK)
linux   /vmlinuz-linux-lts
initrd  /$1-ucode.img
initrd  /initramfs-linux-lts-fallback.img
options root=UUID=$(blkid $2 -s UUID -o value) rw ignore_loglevel audit=0
EOF

cat <<EOF > "$ESP_PATH"/loader/entries/arch-04-non-lts-fallback.conf
title   Arch Linux latest kernel (FALLBACK)
linux   /vmlinuz-linux
initrd  /$1-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=$(blkid $2 -s UUID -o value) rw ignore_loglevel audit=0
EOF

# enable services
systemctl enable firewalld.service
systemctl enable systemd-boot-update.service
systemctl enable sddm.service
systemctl enable libvirtd.service
systemctl enable NetworkManager.service
systemctl enable sshd.service

# update bootloader
bootctl update

# check bootloader config
bootctl list
read wait_until_input
