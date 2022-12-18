#!/usr/bin/env bash

################################################################################
# INITIAL SETUP
################################################################################

# for visudo
export EDITOR=/usr/bin/nvim

# setup sudo access for pratham
/usr/bin/sudo -l -U pratham >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    doas visudo
fi

# set hostname
WHAT_IS_MY_HOSTNAME=$(cat /etc/hostname)
if [[ $WHAT_IS_MY_HOSTNAME != "vasudev" ]]; then
    hostnamectl set-hostname vasudev
    WHAT_IS_MY_HOSTNAME=whoopsie
fi

# set timezone
WHAT_IS_MY_TZ=$(readlink /etc/localtime)
if [[ ! $WHAT_IS_MY_TZ =~ "Asia/Kolkata" ]]; then
    timedatectl set-timezone Asia/Kolkata
    WHAT_IS_MY_TZ=whoopsie
fi

# reboot to bring hostname in effect
if [[ $WHAT_IS_MY_TZ == "whoopsie" || $WHAT_IS_MY_HOSTNAME == "whoopsie" ]]; then
    systemctl reboot
fi

# apply a fix for KDE preventing shutdown/reboots
# this is because I am using systemd-boot instead of GRUB/something else
# https://invent.kde.org/plasma/plasma-workspace/-/wikis/Plasma-and-the-systemd-boot
systemctl --user is-active --quiet service plasma-plasmashell.service
if [[ $? -ne 0 ]]; then
    kwriteconfig5 --file startkderc --group General --key systemdBoot true
    systemctl --user enable plasma-plasmashell.service
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
generate_keys "bluefeds"
generate_keys "flameboi"
generate_keys "gitea"
generate_keys "github"
generate_keys "gitlab"
generate_keys "sentinel"
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


# set the hostname
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
    bash -t
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
rustup component add rust-src rust-analyzer
rustup component add rust-analysis
cargo install cargo-outdated cargo-tree


# neovim (vim-plug)
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'


# get dotfiles
echo -ne "\n\n\n\n"

mkdir -p $HOME/my-git-repos
git_repo_check "dotfiles"
git_repo_check "dotfiles-priv"

rsync \
    --verbose --recursive --size-only --human-readable \
    --progress --stats \
    --itemize-changes --checksum \
    --exclude=".git" --exclude=".gitignore" --exclude="README.md" \
    ~/my-git-repos/dotfiles{,-priv}/ ~/

# podman?
#grep net.ipv4.ping_group_range /etc/sysctl.conf || echo "net.ipv4.ping_group_range=0 $(grep pratham /etc/subuid | awk -F ":" '{print $2 + $3}')" | doas tee -a /etc/sysctl.conf

# flatpak
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

################################################################################
# AUR-RELATED/ZFS
################################################################################

# first, check if ZFS is already installed or not
pacman -Qm | grep "zfs-dkms" > /dev/null
if [[ $? -eq 0 ]]; then
    ZFS_Y_OR_N=n
else
    echo "Do you want to install ZFS, and by extension, \`paru\`? (y/n)"
    read ZFS_Y_OR_N
fi


# build paru as the AUR helper that installs the `zfs-dkms` AUR package
if [[ $ZFS_Y_OR_N == "y" || $ZFS_Y_OR_N == "Y" ]]; then

    # do I have paru?
    if ! command -v paru > /dev/null; then

        # build paru
        doas pacman --sync --refresh --refresh --sysupgrade 
        doas pacman --needed base-devel

        git clone --depth 1  https://aur.archlinux.org/paru.git /tmp/paru-tmp-clone
        pushd /tmp/paru-tmp-clone
        makepkg -si

        if [[ $? -ne 0 ]]; then
            echo "paru wasn't installed successfully :("
            exit 1
        fi

        popd
    fi

    # install ZFS DKMS
    paru -S zfs-dkms
fi

# AUR pkgs
#paru -S noisetorch ssmtp

# wayland-WM
#paru -S hyperland

# intel 
#paru -S libva-intel-driver-g45-h264 intel-hybrid-codec-driver


################################################################################
# WRAP UP
################################################################################

echo -e "\n\nThe setup appears to have completed (as far as I can tell). Please scroll up and verify yourself too!"
echo -e "Below are a few items I can not script myself:\n"
echo "=> please run the \`:PlugInstall\` command in nvim (aliased to vim now)"
echo "=> please uncomment the line in \`~/.config/alacritty/alacritty.yml\` that says $(tput bold)- ~/.config/alacritty/load_linux.yml$(tput sgr0)"
