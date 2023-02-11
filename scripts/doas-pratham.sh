#!/usr/bin/env bash

pushd /home/pratham
mkdir my-git-repos
pushd my-git-repos
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
popd
