# localdev-wsl

Setup local wsl instance for development

## Install WSL instance

Run `setup-host.ps1`

This script will update the WSL engine, download a custom kernel, configure WSL network options and fix nvidia driver linking issues.

## Open this project in DevContainer

Will need to modify `devcontainer.json` by changing `source=/mnt/c/data/localdev-wsl,target=/src,type=bind` to your project path `source=/mnt/c/< your path>/localdev-wsl,target=/src,type=bind`

# Acknowledgments

Most of the code comes from:
https://github.com/jasonwc/setup
