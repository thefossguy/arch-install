#!/usr/bin/env bash

pushd /home/pratham
mkdir my-git-repos
pushd my-git-repos

# dotfiles
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
rm -rf dotfiles
popd

# neovim plugins
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
nvim +'PlugInstall' +'q' +'q'

# alacritty
sed -i 's@#  - ~/.config/alacritty/load_linux.yml@  - ~/.config/alacritty/load_linux.yml@g' /home/pratham/.config/alacritty/alacritty.yml

# gtk dark theme
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

popd
