#!/usr/bin/env bash

################################################################################
# INITIAL SETUP
################################################################################

# for visudo
export EDITOR=/usr/bin/vim

# setup sudo access for pratham
/usr/bin/sudo -l -U pratham > /dev/null
if [[ $? -ne 0 ]]; then
    doas visudo
fi

# set hostname
WHAT_IS_MY_HOSTNAME=$(cat /etc/hostname)
if [[ $WHAT_IS_MY_HOSTNAME != "flameboi" ]]; then
    hostnamectl set-hostname flameboi
    echo "flameboi" | doas tee /etc/hostname
    WHAT_IS_MY_HOSTNAME=whoopsie
fi

# set timezone
WHAT_IS_MY_TZ=$(readlink /etc/localtime)
if [[ ! $WHAT_IS_MY_TZ =~ "Asia/Kolkata" ]]; then
    timedatectl set-timezone Asia/Kolkata
    ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
    WHAT_IS_MY_TZ=whoopsie
fi

# setup network
ETH_DEV_NAME=$(nmcli connection show  | grep ethernet | choose -f "  " 0)
nmcli connection show "$ETH_DEV_NAME" | grep "ipv4.dns:" | grep "1.1.1.2,1.0.0.2" > /dev/null || nmcli connection modify "$ETH_DEV_NAME" ipv4.dns "1.1.1.2,1.0.0.2"
nmcli connection show "$ETH_DEV_NAME" | grep "ipv4.ignore-auto-dns" | grep "yes" > /dev/null || nmcli connection modify "$ETH_DEV_NAME" ipv4.ignore-auto-dns yes
doas nmcli connection reload "$ETH_DEV_NAME"

# reboot to bring hostname in effect
if [[ $WHAT_IS_MY_TZ == "whoopsie" || $WHAT_IS_MY_HOSTNAME == "whoopsie" ]]; then
    systemctl reboot
fi


################################################################################
# SSH KEYS
################################################################################

# checking func
function generate_keys()
{
    if [[ ! -f "$1" && ! -f "$1"".pub" ]]; then
        ssh-keygen -t ed25519 -f $1
    fi
}

# create ssh keys
if [[ ! -d $HOME/.ssh ]]; then
    mkdir $HOME/.ssh
    chmod 700 $HOME/.ssh
fi
pushd $HOME/.ssh
for KEY in {gitea,github,gitlab,reddish,sentinel,vasudev,riscyrock,rustyvm}; do
    generate_keys "$KEY"
done
popd


################################################################################
# CUSTOM HOSTNAME FOR git.thefossguy.com
################################################################################

# check for an empty hostname in ~/.ssh/config
if [[ ! -f $HOME/.ssh/config ]]; then
    EDIT_SSH_CONF=true
else
    CONTENTS_OF_SSH_CONF=$(grep -A 1 "git.thefossguy.com" ~/.ssh/config | tail -n 1 | rev)

    if [[ "${CONTENTS_OF_SSH_CONF::1}" != "5" ]]; then
        EDIT_SSH_CONF=true
    else
        EDIT_SSH_CONF=false
    fi

fi

# set the hostname in ssh config
if [[ $EDIT_SSH_CONF == true ]]; then
    tput -x clear
    cat <<EOF > $HOME/.ssh/config
Host git.thefossguy.com
    Hostname ::?
    User git
    IdentityFile ~/.ssh/gitea
    Port 22
EOF
    cat $HOME/.ssh/gitea.pub
    echo -e "\n\n\n\nPopulate Hostname (IP addr) for \"git.thefossguy.com\" in ~/.ssh/config"
    /usr/bin/vim ~/.ssh/config
fi


################################################################################
# SETUP DEV ENVIRONMENT
################################################################################

# clone repos
function git_repo_check()
{
    pushd $HOME/my-git-repos
    if [[ ! -d "$1" ]]; then
        git clone git@git.thefossguy.com:thefossguy/"$1"
    else
        pushd "$1"
        git fetch
        git pull
        popd
    fi
    popd
}

# update everything (along with `rustup`)
doas pacman --sync --refresh --refresh --sysupgrade

# rust-lang
rustup default stable
rustup update stable
rustup component add rust-src rust-analyzer rust-analysis

# get dotfiles
echo -ne "\n\n\n\n"
mkdir -p $HOME/my-git-repos
git_repo_check "dotfiles"
git_repo_check "dotfiles-priv"

rsync \
    --verbose --recursive --size-only --human-readable \
    --progress --stats \
    --itemize-changes --checksum \
    --exclude=".git" --exclude=".gitignore" --exclude="README.md" --exclude="run_me.sh" \
    ~/my-git-repos/dotfiles{,-priv}/ ~/

# dark mode (gtk)
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

# podman
if ! command -v podman > /dev/null; then
    grep net.ipv4.ping_group_range /etc/sysctl.conf || echo "net.ipv4.ping_group_range=0 $(grep pratham /etc/subuid | awk -F ":" '{print $2 + $3}')" | doas tee -a /etc/sysctl.conf
    grep "kernel.unprivileged_userns_clone=1" /etc/sysctl.conf || echo "kernel.unprivileged_userns_clone=1" | doas tee -a /etc/sysctl.conf
    podman system migrate
fi

# tldr
tldr --update

# flatpak
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub com.brave.Browser com.discordapp.Discord com.github.maoschanz.drawing com.github.tchx84.Flatseal com.uploadedlobster.peek io.gitlab.librewolf-community org.flameshot.Flameshot org.gnome.Logs org.gnome.gitlab.YaLTeR.Identity org.gnome.gitlab.YaLTeR.VideoTrimmer org.gnome.meld org.kde.okular org.raspberrypi.rpi-imager


################################################################################
# VIRSH POOLS + NETWORK
################################################################################

groups | grep "libvirt" > /dev/null || doas adduser pratham libvirt
groups | grep "kvm" > /dev/null || doas adduser pratham kvm

# network
doas virsh net-info default | grep "Autostart" | grep "no" > /dev/null && doas virsh net-autostart default

# storage pool
LIBVIRTD_RESTART=no
doas virsh pool-dumpxml default | grep "/flameboi_st/vm-store" > /dev/null
if [[ $? -ne 0 ]]; then
    doas virsh pool-destroy default
    doas virsh pool-undefine default
    doas virsh pool-define-as --name default --type dir --target /flameboi_st/vm-store
    doas virsh pool-autostart default
    doas virsh pool-start default
    LIBVIRTD_RESTART=yes
fi

# restart libvirtd if necessary
if [[ "$LIBVIRTD_RESTART" == "yes" ]]; then
    doas systemctl restart libvirtd
fi


################################################################################
# AUR/PARU
################################################################################

if ! command -v paru > /dev/null; then
    pushd /tmp
    wget "https://github.com/Morganamilo/paru/releases/download/v1.11.2/paru-v1.11.2-x86_64.tar.zst"
    tar xf "paru-v1.11.2-x86_64.tar.zst"
    ./paru -Sy --noconfirm paru-bin
    popd
fi

# install packages if not installed
pacman -Qm | grep "ttf-apple-emoji" > /dev/null || paru -S --noconfirm ttf-apple-emoji
pacman -Qm | grep "ttf-fork-awesome" > /dev/null || paru -S --noconfirm ttf-fork-awesome

# AUR pkgs
#paru -S noisetorch ssmtp

# wayland-WM
#paru -S hyperland

# intel 
#paru -S libva-intel-driver-g45-h264 intel-hybrid-codec-driver


################################################################################
# ZFS setup
################################################################################

pacman -Qm | grep "zfs-dkms" > /dev/null || paru -S --noconfirm zfs-dkms

if command -v zpool > /dev/null; then
    lsmod | grep zfs > /dev/null
    if [[ $? -ne 0 ]]; then
        doas modprobe zfs
    fi
fi

doas systemctl unmask zfs-import-cache.service zfs-import-scan.service zfs-load-key.service zfs-mount.service zfs-volume-wait.service zfs-zed.service
doas systemctl enable zfs-import-cache.service zfs-import-scan.service zfs-load-key.service zfs-mount.service zfs-volume-wait.service zfs-zed.service

zpool list | grep "flameboi_st" > /dev/null  || doas zpool import 16601987433518749526
zpool list | grep "heathen_disk" > /dev/null || doas zpool import 12327394492612946617

doas zpool set cachefile=/etc/zfs/zpool.cache heathen_disk


################################################################################
# WRAP UP
################################################################################

tput -x clear
echo -e "The setup appears to have completed (as far as I can tell). Please scroll up and verify yourself too!"
echo ""
echo -e "Open Firefox and do the following:
1. Open \"about:config\"
2. Search for boolean \"browser.search.separatePrivateDefault.ui.enabled\"
3. Switch the value to \"true\"
4. Search for \"widget.non-native-theme.scrollbar.style\"
5. Set the value to 4 (valid values' range: 0..6)
6. Sign into the Firefox account

---

Add the line 'After=zfs.target' to '/usr/lib/systemd/system/libvirtd.service'
"
