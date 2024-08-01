#!/bin/bash

set -euo pipefail

copy_solution () {
  rootDirectory=${1}
  localDevDirectory=${2}

  if [ ! -d "$localDevDirectory" ]; then
    mkdir -p "$localDevDirectory"
  fi

  cp -rf -R -u -p "$rootDirectory/roles/" "$localDevDirectory/"
  cp -rf -R -u -p "$rootDirectory/vars/" "$localDevDirectory/"
  cp -rf -R -u -p "$rootDirectory/ansible.cfg" "$localDevDirectory/ansible.cfg"
  cp -rf -R -u -p "$rootDirectory/hosts" "$localDevDirectory/hosts"
  cp -rf -R -u -p "$rootDirectory/playbook.yml" "$localDevDirectory/playbook.yml"
  cp -rf -R -u -p "$rootDirectory/requirements.yml" "$localDevDirectory/requirements.yml"
}

setup_overrides () {
  localDevDirectory=${1}
  localDevOverrideDirectory=${2}
  natNetwork=${3}
  natIpAddress=${4}

  if [ -d "$localDevOverrideDirectory" ]; then
    cd "$localDevOverrideDirectory"
    pwd
  else
    mkdir -p "$localDevOverrideDirectory/vars"
    cd "$localDevOverrideDirectory"
    pwd

    cp -rf -R -u -p "$localDevDirectory/vars/" "$localDevOverrideDirectory/"

    sed -i "s/10.152.0.0\/16/${natNetwork//[.\/\\*^\$\[]/\\&}/g" "$localDevOverrideDirectory/vars/network.yml"
    sed -i "s/10.152.0.5/${natIpAddress//[.\/\\*^\$\[]/\\&}/g" "$localDevOverrideDirectory/vars/network.yml"

    export LOCALDEV_OVERRIDE_PATH=$localDevOverrideDirectory

    sudo tee /etc/profile.d/local_dev_override.sh > /dev/null <<EOF
LOCALDEV_OVERRIDE_PATH=$localDevOverrideDirectory
EOF
  fi
}

# Function to fix permissions of .ssh folder and its contents
fix_permissions() {
  # Set correct permissions for the .ssh folder
  chmod 700 ~/.ssh

  # Set correct permissions for files within .ssh folder
  chmod 600 ~/.ssh/*

  # Set correct permissions for public key files
  if compgen -G "$HOME/.ssh/*.pub" > /dev/null; then
    chmod 644 ~/.ssh/*.pub
  fi
}

# Function to generate SSH key pair if not exists
generate_ssh_key() {
  # Check if the key files exist
  if [ ! -f ~/.ssh/id_rsa ] || [ ! -f ~/.ssh/id_rsa.pub ]; then
    # If not, generate a new SSH key pair
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
  fi
}

# Main function
setup_ssh() {
  # Check if .ssh folder exists
  if [ ! -d ~/.ssh ]; then
    echo "Creating .ssh folder..."
    mkdir ~/.ssh
  fi

  if [ ! -f ~/.ssh/known_hosts ]; then
    echo "Creating .ssh known_hosts file..."
    touch ~/.ssh/known_hosts
  fi

  # Fix permissions
  echo "Fixing permissions..."
  fix_permissions

  # Generate SSH key if not exists
  echo "Generating SSH key pair if not exists..."
  generate_ssh_key
}

ROOT_DIRECTORY=$(realpath $( dirname $(dirname ${BASH_SOURCE[0]:-$0} ) ) )
WINDOWS_SSH_PATH=${1-""}
NAT_NETWORK=${2-""}
NAT_IP_ADDRESS=${3-""}

LOCAL_DEV_DIRECTORY=$HOME/localdev-wsl
LOCAL_DEV_OVERRIDE_DIRECTORY=$HOME/override-localdev-wsl

copy_solution "$ROOT_DIRECTORY" "$LOCAL_DEV_DIRECTORY"
setup_overrides "$LOCAL_DEV_DIRECTORY" "$LOCAL_DEV_OVERRIDE_DIRECTORY" "$NAT_NETWORK" "$NAT_IP_ADDRESS"

cp -rf -R -u -p "$(/usr/bin/wslpath -a -u "$WINDOWS_SSH_PATH")" "$HOME/"
setup_ssh

# shellcheck disable=SC2236,SC2143
if [ ! -n "$(grep "^github.com " ~/.ssh/known_hosts)" ]; then 
  ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null
fi

cd $HOME/localdev-wsl
ansible-galaxy install -r requirements.yml
