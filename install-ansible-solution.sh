#!/bin/bash
set -e
# Function to fix permissions of .ssh folder and its contents
fix_permissions() {
  # Set correct permissions for the .ssh folder
  chmod 700 ~/.ssh

  # Set correct permissions for files within .ssh folder
  chmod 600 ~/.ssh/*

  # Set correct permissions for public key files
  chmod 644 ~/.ssh/*.pub
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

setup_ssh

# shellcheck disable=SC2236,SC2143
if [ ! -n "$(grep "^github.com " ~/.ssh/known_hosts)" ]; then ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null; fi

if [ -d "$HOME"/localdev-wsl ]; then
  cd "$HOME"/localdev-wsl
  pwd
  git pull --rebase
else
  cd "$HOME"
  pwd
  git clone https://github.com/taliesins/localdev-wsl
fi

ansible-galaxy install -r requirements.yml
