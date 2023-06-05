#!/usr/bin/env bash
PRATHAMS_HOME=/home/pratham

pushd ${PRATHAMS_HOME}
git clone --depth 1 --bare https://git.thefossguy.com/thefossguy/dotfiles.git ${PRATHAMS_HOME}/.dotfiles
git --git-dir=${PRATHAMS_HOME}/.dotfiles --work-tree=${PRATHAMS_HOME} checkout -f
popd
