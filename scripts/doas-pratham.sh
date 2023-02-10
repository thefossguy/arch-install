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

git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim
nvim +'PackerSync' +'q' +'q'
nvim +'checkhealth telescope' +'q' +'q'
nvim +'TSUpdate' +'q' +'q'

popd
