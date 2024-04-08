# localdev-wsl

Setup local wsl instance for development

## Install WSL instance

Run `setup-host.ps1`

This script will update the WSL engine, download a custom kernel, configure WSL network options and fix nvidia driver linking issues. Then it will install Docker, MicroK8S and then will configure Kubernetes.

During setup you will be asked interactively to set:
* Username
* Password
* Password confirmation
* Once instance is setup type `exit<enter>` to continue installation
* Become password

### Customization of Ansible variables

To set overriden variables:
* `wsl`
* `cd $HOME/localdev-wsl-overrides`
* Configure as required

## Open this project in DevContainer

Will need to modify `devcontainer.json` by changing `source=/mnt/c/data/localdev-wsl,target=/src,type=bind` to your project path `source=/mnt/c/< your path>/localdev-wsl,target=/src,type=bind`

# Acknowledgments

Most of the code comes from:
https://github.com/jasonwc/setup
