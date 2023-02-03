#!/usr/bin/env bash

pushd /home/pratham
mkdir my-git-repos
pushd my-git-repos

################################################################################
# DOTFILE CLONING
################################################################################

git clone --depth 1 https://git.thefossguy.com/thefossguy/dotfiles.git
pushd dotfiles
tput -x clear
rsync \
    --verbose --recursive --size-only --human-readable \
    --progress --stats \
    --itemize-changes --checksum --perms \
    --exclude=".git" --exclude=".gitignore" --exclude="README.md" --exclude="run_me.sh" \
    ../dotfiles/ ~/
popd
popd


################################################################################
# NEOVIM PLUGINS
################################################################################

sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

nvim +'PlugInstall' +'q' +'q'
nvim +'checkhealth telescope' +'q' +'q'


################################################################################
# PARU
################################################################################

mkdir paru
pushd paru
wget "https://github.com/Morganamilo/paru/releases/download/v1.11.2/paru-v1.11.2-x86_64.tar.zst"
tar xf "paru-v1.11.2-x86_64.tar.zst"
./paru -Sy paru-bin
popd

rm -rf paru


popd
