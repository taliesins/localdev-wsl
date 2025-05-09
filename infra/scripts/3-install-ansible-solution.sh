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
  echo "natNetwork: $natNetwork"
  echo "natIpAddress: $natIpAddress"

  if [ -d "$localDevOverrideDirectory" ]; then
    cd "$localDevOverrideDirectory"
    echo "Directory already exists, skipping copy."
    echo "Current directory:"
    pwd
  else
    echo "Creating override directory: $localDevOverrideDirectory/vars"
    mkdir -p "$localDevOverrideDirectory/vars"
    cd "$localDevOverrideDirectory"
    echo "Copying files to override directory..."
    echo "Current directory:"
    pwd

    echo "Copying files from $localDevDirectory to $localDevOverrideDirectory"
    cp -rf -R -u -p "$localDevDirectory/vars/" "$localDevOverrideDirectory/"
    echo "sed -i s/10.152.0.0\/16/${natNetwork//[.\/\\*^\$\[]/\\&}/g $localDevOverrideDirectory/vars/network.yml"
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
if [ -z "$WINDOWS_SSH_PATH" ]; then
  echo "Please provide the path to your SSH key on Windows."
  exit 1
fi
LOCAL_DEV_OVERRIDE_DIRECTORY=$HOME/override-localdev-wsl

echo "ROOT_DIRECTORY: $ROOT_DIRECTORY"
echo "WINDOWS_SSH_PATH: $WINDOWS_SSH_PATH"
echo "NAT_NETWORK: $NAT_NETWORK"
echo "NAT_IP_ADDRESS: $NAT_IP_ADDRESS"
echo "LOCAL_DEV_DIRECTORY: $LOCAL_DEV_DIRECTORY"
echo "LOCAL_DEV_OVERRIDE_DIRECTORY: $LOCAL_DEV_OVERRIDE_DIRECTORY"
echo "1. copy solution from $ROOT_DIRECTORY to $LOCAL_DEV_DIRECTORY"
copy_solution "$ROOT_DIRECTORY" "$LOCAL_DEV_DIRECTORY"
echo "2. copy override solution from $LOCAL_DEV_DIRECTORY to $LOCAL_DEV_OVERRIDE_DIRECTORY"
setup_overrides "$LOCAL_DEV_DIRECTORY" "$LOCAL_DEV_OVERRIDE_DIRECTORY" "$NAT_NETWORK" "$NAT_IP_ADDRESS"

cp -rf -R -u -p "$(/usr/bin/wslpath -a -u "$WINDOWS_SSH_PATH")" "$HOME/"
setup_ssh

# shellcheck disable=SC2236,SC2143
if [ ! -n "$(grep "^github.com " ~/.ssh/known_hosts)" ]; then 
  ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null
fi

cd $HOME/localdev-wsl
echo "Installing Ansible requirements with ansible-galaxy install -r requirements.yml"
ansible-galaxy install -r requirements.yml
