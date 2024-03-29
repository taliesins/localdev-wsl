#!/bin/bash
set -e
cd $HOME/localdev-wsl
ansible-playbook -K playbook.yaml
