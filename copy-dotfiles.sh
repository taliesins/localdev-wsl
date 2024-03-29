#!/bin/bash
set -e
# shellcheck disable=SC2016
cp -R -u -p "$(/usr/bin/wslpath -a -u '$windows_ssh_path')" ~/
