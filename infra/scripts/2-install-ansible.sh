#!/bin/bash
echo "Installing Ansible and Python 3.12"

set -euo pipefail
echo "Setting script to exit on error and undefined variables."

# Add Ansible PPA and update package lists
# sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
echo "Updating package lists..."

# Upgrade existing packages
sudo apt upgrade -y
echo "Upgrading existing packages..."


# Install uv package manager if not already installed
if ! command -v uv &> /dev/null; then
  echo "Installing uv package manager..."
  # On macOS and Linux. 
  curl -LsSf https://astral.sh/uv/install.sh | sh
  chmod +x $HOME/.local/bin/uv
  echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
  echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.profile
  source ~/.bashrc
  source ~/.profile
else
  echo "uv package manager is already installed."   
fi



if [ ! -d "$HOME/.local/bin/py312" ]; then
  echo "Directory $HOME/.local/bin/py312 does not exist. Initializing py312..."
  sudo $HOME/.local/bin/uv init py312
fi
cd $HOME/.local/bin/py312


echo "Installing Python 3.12 using uv..."
sudo $HOME/.local/bin/uv python install 3.12


# Install Python packages
echo "Installing Python package netaddr..."
sudo $HOME/.local/bin/uv add netaddr==1.3.0

# Install other required packages
echo "Installing other required packages..."
sudo apt install -y ansible aptitude
