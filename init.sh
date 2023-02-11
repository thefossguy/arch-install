#!/usr/bin/env bash

pacman-key --init
pacman -Syy
pacman -S archlinux-keyring --noconfirm
pacman -S git --noconfirm
git clone https://git.thefossguy.com/thefossguy/arch-install.git
pushd arch-install
