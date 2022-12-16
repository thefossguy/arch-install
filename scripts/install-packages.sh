#!/usr/bin/env bash


################################################################################
# install packages
################################################################################

# update pacman db
pacman --sync --refresh --refresh


# absolutely necessary for _MY_ experience
PKGS_TO_INSTALL=(base bash cron curl dhcpcd dnsutils doas efibootmgr findutils grub iputils less libdrm linux-lts linux-firmware lsb-release lsof man man-db man-pages nano neovim openssh openssl os-prober pacman-contrib reflector rsync tmux wireguard-tools zsh zsh-completions zsh-syntax-highlighting)

# power management
PKGS_TO_INSTALL+=(acpi_call iasl)

# add-on
PKGS_TO_INSTALL+=(flatpak ffmpeg light)

# monitoring
PKGS_TO_INSTALL+=(btop htop iotop iperf iperf3 nload)

# containersation stuff
#PKGS_TO_INSTALL+=(aardvark-dns bridge-utils fuse-overlayfs podman podman-compose podman-dnsname slirp4netns)

# download clients
PKGS_TO_INSTALL+=(aria2 wget yt-dlp)

# android-stuff
PKGS_TO_INSTALL+=(android-tools)

# *utils-rust
PKGS_TO_INSTALL+=(bat fd ripgrep tre)

# system utilities
PKGS_TO_INSTALL+=(hd-idle hdparm pkgfile tldr smartmontools wol)

# compression
PKGS_TO_INSTALL+=(tar unrar unzip xz zip)

# software devel
PKGS_TO_INSTALL+=(rustup)

# kernel devel
PKGS_TO_INSTALL+=(base-devel bc cpio gcc git inetutils kmod libelf linux-lts-headers make perl tar xmlto xz)

# virtualisation


# network filesystems
PKGS_TO_INSTALL+=(avahi nfs-utils samba smbclient)
#PKGS_TO_INSTALL+=(kdenetwork-filesharing)
#PKGS_TO_INSTALL+=(gvfs-smb

# zfs


# GPU
#PKGS_TO_INSTALL+=(mesa qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-gl qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-gpu-pci-gl qemu-hw-s390x-virtio-gpu-ccw)
#PKGS_TO_INSTALL+=(libva-mesa-driver mesa radeontop vulkan-radeon)
#PKGS_TO_INSTALL+=(intel-media-driver libva-intel-driver mesa vulkan-intel)
PKGS_TO_INSTALL+=(nvidia-lts nvidia-utils)

# Display Server (Wayland)
PKGS_TO_INSTALL+=(libdrm wayland)

# Window Manager (Wayland)


# Desktop Environment (Wayland)
#PKGS_TO_INSTALL+=(kcalc kcharselect kdf kdialog ktimer print-manager plasma plasma-meta kde-system-meta plasma-wayland-session)
PKGS_TO_INSTALL+=(xfce4)

# GUI
PKGS_TO_INSTALL+=(alacritty firefox meld mpv slurp otf-overpass)

# Sound
PKGS_TO_INSTALL+=(pipewire pipewire-pulse)
#PKGS_TO_INSTALL+=(alsa-firmware alsa-lib alsa-utils gst-plugins-good gstreamer libao libcanberra-gstreamer libcanberra-pulse pulseaudio pulseaudio-alsa)

# ???
#PKGS_TO_INSTALL+=(exfatprogs netcfg)

# xorg
#PKGS_TO_INSTALL+=(libdrm libva-mesa-driver qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-gl qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-gpu-pci-gl qemu-hw-s390x-virtio-gpu-ccw xf86-input-libinput xf86-input-synaptics xf86-input-wacom xf86-video-qxl xf86-video-vmware xorg xorg-apps xorg-fonts-alias xorg-fonts-encodings xorg-fonts-misc xorg-server xorg-xauth xorg-xinit xorg-xkbutils)
#PKGS_TO_INSTALL+=(intel-media-driver libva-intel-driver vulkan-intel)
#PKGS_TO_INSTALL+=(xf86-video-amdgpu radeontop vulkan-radeon)


# install x86 microcode
if [[ "$1" == "amd" ]]; then
    PKGS_TO_INSTALL+=(amd-ucode)
elif [[ "$1" == "intel" ]]; then
    PKGS_TO_INSTALL+=(intel-ucode)
fi

pacstrap -K /mnt "${PKGS_TO_INSTALL[@]}"
