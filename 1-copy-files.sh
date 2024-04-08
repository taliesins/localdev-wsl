#!/bin/bash
set -e
mkdir -p $HOME/localdev-wsl-scripts

# shellcheck disable=SC2016
cp -rf -u -p $(/usr/bin/wslpath -a -u '$windows_cwd_path')/*.sh $HOME/localdev-wsl-scripts/
cp -rf -R -u -p $(/usr/bin/wslpath -a -u '$windows_ssh_path') $HOME/
