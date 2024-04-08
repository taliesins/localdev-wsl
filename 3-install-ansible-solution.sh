#!/bin/bash
set -e
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

setup_ssh

# shellcheck disable=SC2236,SC2143
if [ ! -n "$(grep "^github.com " ~/.ssh/known_hosts)" ]; then 
  ssh-keyscan github.com >> ~/.ssh/known_hosts 2> /dev/null
fi

if [ -d $HOME/localdev-wsl ]; then
  cd $HOME/localdev-wsl
  pwd
  git pull --rebase
else
  cd $HOME
  pwd
  git clone $git_repo_uri 
  cd $HOME/localdev-wsl
fi

if [ -d $HOME/localdev-wsl-overrides ]; then
  cd $HOME/localdev-wsl-overrides
  pwd
else
  mkdir -p $HOME/localdev-wsl-overrides/vars
  cd $HOME/localdev-wsl-overrides
  pwd

  cp -rf $HOME/localdev-wsl/vars/network.yml $HOME/localdev-wsl-overrides/vars/network.yml
  cp -rf $HOME/localdev-wsl/vars/user_environment.yml $HOME/localdev-wsl-overrides/vars/user_environment.yml
  cp -rf $HOME/localdev-wsl/vars/prerequisite_packages.yml $HOME/localdev-wsl-overrides/vars/prerequisite_packages.yml
  cp -rf $HOME/localdev-wsl/vars/tool_versions.yml $HOME/localdev-wsl-overrides/vars/tool_versions.yml

  sed -i 's/10.152.0.0\/16/$nat_network/g' $HOME/localdev-wsl-overrides/vars/network.yml
  sed -i 's/10.152.0.5/$nat_ip_address/g' $HOME/localdev-wsl-overrides/vars/network.yml

  export LOCALDEV_OVERRIDE_PATH=../localdev-wsl-overrides/

  sudo tee /etc/profile.d/local_dev_override.sh > /dev/null <<'EOF'
LOCALDEV_OVERRIDE_PATH=../localdev-wsl-overrides/
EOF

fi

cd $HOME/localdev-wsl
ansible-galaxy install -r requirements.yml
