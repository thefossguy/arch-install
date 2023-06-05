#!/usr/bin/env bash
PRATHAM_HOME=/home/pratham

pushd ${PRATHAM_HOME}
git clone --depth 1 --bare https://git.thefossguy.com/thefossguy/dotfiles.git
git --git-dir=${PRATHAM_HOME}/my-git-repos/dotfiles --work-tree=${PRATHAM_HOME} checkout
popd
