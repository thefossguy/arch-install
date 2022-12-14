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
if [[ $WHAT_IS_MY_HOSTNAME != "flameboi" ]]; then
    hostnamectl set-hostname flameboi
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


################################################################################
# DARK THEME SETUP
################################################################################

mkdir -p $HOME/.config/gtk-3.0

cat <<EOF > $HOME/.config/gtk-3.0/settings.ini
[Settings]
gtk-application-prefer-dark-theme=true
EOF

gsettings set org.gnome.desktop.interface color-scheme prefer-dark


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
flatpak install flathub com.github.tchx84.Flatseal

################################################################################
# AUR-RELATED/ZFS
################################################################################

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

# install packages if not installed
pacman -Qm | grep "ttf-apple-emoji" > /dev/null || paru -S ttf-apple-emoji
pacman -Qm | grep "ttf-fork-awesome" > /dev/null || paru -S ttf-fork-awesome
pacman -Qm | grep "zfs-linux-lts" > /dev/null || paru -S zfs-linux-lts

# AUR pkgs
#paru -S noisetorch ssmtp

# wayland-WM
#paru -S hyperland

# intel 
#paru -S libva-intel-driver-g45-h264 intel-hybrid-codec-driver


################################################################################
# WRAP UP
################################################################################

tput -x clear
echo -e "\n\nThe setup appears to have completed (as far as I can tell). Please scroll up and verify yourself too!"
echo -e "Below are a few items I can not script myself:\n"
echo "=> please run the \`:PlugInstall\` command in nvim (aliased to vim now)"
echo "=> please uncomment the line in \`~/.config/alacritty/alacritty.yml\` that says $(tput bold)- ~/.config/alacritty/load_linux.yml$(tput sgr0)"
if ! command -v zpool > /dev/null; then
    lsmod | grep zfs
    if [[ $? -ne 0 ]]; then
        echo "ZFS Kernel module is not loaded. Please run the \`sudo modprobe zfs\` command and reboot."
    fi
    sudo systemctl enable --now zfs-import-cache.service zfs-import-scan.service zfs-mount.service zfs-share.service zfs.target zfs-zed.service
    sudo zpool set cachefile=/etc/zfs/zpool.cache heathen_disk
fi
echo -e "\n\nDotfiles have been copied, but some files are yet to be copied. Your manual intervention is necessary. Please copy the contents of the \"_OTHER\" directory manually."
