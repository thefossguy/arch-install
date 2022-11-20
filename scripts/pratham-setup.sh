#!/usr/bin/env bash

################################################################################
# INITIAL SETUP
################################################################################

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
kwriteconfig5 --file startkderc --group General --key systemdBoot true

################################################################################
# SSH KEYS
################################################################################

# create ssh keys
if [[ ! -d $HOME/.ssh ]]; then
    mkdir $HOME/.ssh
    chmod 700 $HOME/.ssh
fi
pushd $HOME/.ssh
ssh-keygen -t ed25519 -f bluefeds
ssh-keygen -t ed25519 -f flameboi
ssh-keygen -t ed25519 -f gitea
ssh-keygen -t ed25519 -f github
ssh-keygen -t ed25519 -f gitlab
ssh-keygen -t ed25519 -f sentinel
popd

# IP address for server is hidden behind cloudflare proxy
tput -x clear
cat <<EOF > $HOME/.ssh/config
Host git.thefossguy.com
    Hostname ::?
    User git
    IdentityFile ~/.ssh/gitea
    Port 22
EOF
cat $HOME/.ssh/gitea.pub
echo "Populate Hostname (IP addr) for \"git.thefossguy.com\" in ~/.ssh/config"
bash


################################################################################
# SETUP DEV ENVIRONMENT
################################################################################

# rust-lang
#curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh (removed because paru has a hard dependency on Arch's cargo; this is handled by the `rustup` package)
rustup default stable
rustup component add rust-src rust-analyzer
rustup component add rust-analysis
cargo install cargo-outdated cargo-tree


# neovim (vim-plug)
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'


# get dotfiles
echo -ne "\n\n\n\n"

mkdir -p $HOME/my-git-repos
pushd $HOME/my-git-repos/
git clone git@git.thefossguy.com:thefossguy/dotfiles-priv.git
git clone git@git.thefossguy.com:thefossguy/dotfiles.git
popd

rsync \
    --verbose --recursive --size-only --human-readable \
    --progress --stats \
    --itemize-changes --checksum \
    --exclude=".git" --exclude=".gitignore" --exclude="README.md" \
    ~/dotfiles/ ~/

rsync \
    --verbose --recursive --size-only --human-readable \
    --progress --stats \
    --itemize-changes --checksum \
    --exclude=".git" --exclude=".gitignore" \
    ~/dotfiles-priv/ ~/

# podman?
#grep net.ipv4.ping_group_range /etc/sysctl.conf || echo "net.ipv4.ping_group_range=0 $(grep pratham /etc/subuid | awk -F ":" '{print $2 + $3}')" | doas tee -a /etc/sysctl.conf


################################################################################
# AUR-RELATED
################################################################################

# install necessary packages for installing \`paru\`
doas pacman --sync --refresh --needed base-devel

# build paru
mkdir /tmp/parutemp-PARU && pushd /temp/parutemp-PARU
git clone --depth 1 https://aur.archlinux.org/paru.git
pushd paru
makepkg -si
if [[ $? -ne 0 ]]; then
    tput -x clear
    echo "paru wasn't installed successfully :("
    exit 1
fi
popd
popd

# AUR pkgs
paru -S qomui noisetorch ssmtp
paru -S zfs-dkms

# wayland-WM
#paru -S hyperland

# intel 
#paru -S libva-intel-driver-g45-h264 intel-hybrid-codec-driver


################################################################################
# WRAP UP
################################################################################

tput -x clear
echo "vim-plug for nvim has been installed, please fetch the plugins using the \'`:PlugInstall\` command"
