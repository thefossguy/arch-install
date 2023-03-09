#!/usr/bin/env bash

# force update pacman db
pacman --sync --refresh --refresh

################################################################################
# SELECT PACKAGES TO BE INSTALLED
################################################################################

# absolutely necessary for _MY_ experience
PKGS_TO_INSTALL=(base bash bind cron curl dash dhcpcd efibootmgr findutils iputils keepassxc ksh less libdrm linux linux-firmware linux-lts lsb-release lsof man man-db man-pages nano neovim networkmanager opendoas openssh openssl os-prober pacman-contrib reflector rsync tmux wireguard-tools zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting)

# power management
PKGS_TO_INSTALL+=(acpi_call lm_sensors xfce4-power-manager)

# firewall
PKGS_TO_INSTALL+=(firewalld)

# add-on
PKGS_TO_INSTALL+=(ffmpeg flatpak imagemagick light mediainfo)

# monitoring
PKGS_TO_INSTALL+=(bandwhich btop htop inxi iotop iperf iperf3 nload)

# containersation stuff
#PKGS_TO_INSTALL+=(aardvark-dns bridge-utils fuse-overlayfs podman podman-compose podman-dnsname slirp4netns)

# download clients
PKGS_TO_INSTALL+=(aria2 wget yt-dlp)

# android-stuff
PKGS_TO_INSTALL+=(android-tools)

# *utils-rust
PKGS_TO_INSTALL+=(bat choose dog dua-cli dust exa fd hyperfine procs ripgrep skim tealdeer tre tree)

# system utilities
PKGS_TO_INSTALL+=(hd-idle hdparm mlocate smartmontools usbutils wol)

# compression
PKGS_TO_INSTALL+=(tar unrar unzip xz zip)

# software devel
PKGS_TO_INSTALL+=(cargo-audit cargo-auditable cargo-bloat cargo-depgraph cargo-outdated cargo-spellcheck cargo-update cargo-watch lazygit picocom rustup)
# cross compilation
PKGS_TO_INSTALL+=(aarch64-linux-gnu-gcc riscv64-elf-gcc riscv64-linux-gnu-gcc)

# kernel devel
PKGS_TO_INSTALL+=(base-devel bc cpio gcc git inetutils kmod libelf linux-headers linux-lts-headers make perl tar xmlto xz)

# virtualisation
PKGS_TO_INSTALL+=(dnsmasq guestfs-tools libvirt qemu-desktop virt-manager)

# network filesystems
PKGS_TO_INSTALL+=(avahi cifs-utils nfs-utils)
#PKGS_TO_INSTALL+=(gvfs-smb samba smbclient)

# GPU
#PKGS_TO_INSTALL+=(mesa qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-gl qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-gpu-pci-gl xf86-video-qxl)
#PKGS_TO_INSTALL+=(libva-mesa-driver mesa radeontop vulkan-radeon)
#PKGS_TO_INSTALL+=(intel-media-driver libva-intel-driver mesa vulkan-intel)
PKGS_TO_INSTALL+=(nvidia-lts nvidia-settings nvidia-utils)

# display server (Wayland)
#PKGS_TO_INSTALL+=(libdrm wayland)

# display server (xorg)
PKGS_TO_INSTALL+=(libdrm libva-mesa-driver xf86-input-libinput xf86-input-synaptics xorg xorg-fonts-encodings xorg-fonts-misc xorg-server xorg-xauth xorg-xbacklight xorg-xdpyinfo xorg-xinit xorg-xkbutils xorg-xprop xorg-xrandr xorg-xsetroot xsecurelock xsel xclip)
#PKGS_TO_INSTALL+=(intel-media-driver libva-intel-driver vulkan-intel)
#PKGS_TO_INSTALL+=(radeontop vulkan-radeon xf86-video-amdgpu)

# bspwm (X11 for now because NVIDIA)
PKGS_TO_INSTALL+=(bspwm dunst feh i3lock jq lxsession picom polybar rofi sddm socat sxhkd wmctrl xdg-desktop-portal-gtk)

# GUI packages
PKGS_TO_INSTALL+=(alacritty bitwarden firefox gnome-disk-utility ksnip meld mpv neovide otf-overpass pavucontrol slurp thunar)

# sound (pipewire)
PKGS_TO_INSTALL+=(pamixer pipewire pipewire-pulse wireplumber)
#PKGS_TO_INSTALL+=(alsa-firmware alsa-lib alsa-utils gst-plugins-good gstreamer libao libcanberra-gstreamer libcanberra-pulse pulseaudio pulseaudio-alsa)

# install x86 microcode
if [[ "$1" == "amd" ]]; then
    PKGS_TO_INSTALL+=(amd-ucode)
elif [[ "$1" == "intel" ]]; then
    PKGS_TO_INSTALL+=(intel-ucode)
fi

pacstrap -K /mnt "${PKGS_TO_INSTALL[@]}"
