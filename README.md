# localdev-wsl

Setup local wsl instance for development

## Setup WSL instance

Run `1-setup-wsl.ps1`

This script will update the WSL engine, download a custom kernel, configure WSL network options and fix nvidia driver linking issues. Then it will install Docker, MicroK8S and then will configure Kubernetes.

## Setup local instance

Run `2-setup-local.ps1`

This script will download Docker CLI, Docker Compose and Docker BuildX. It will configure Docker CLI to use Docker running on WSL. It will setup and configure Unbound to wildcard dns domains to ingress running in Kubernetes on WSL.

## Uninstall WSL instance

Run `wsl --unregister Ubuntu-22.04`

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
