#!/bin/bash

set -euo pipefail

cd $HOME/localdev-wsl
ansible-playbook playbook.yml 
