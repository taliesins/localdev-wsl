#!/bin/bash

set -euo pipefail

sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt upgrade -y
sudo apt install python3 python3-pip ansible aptitude -y
sudo pip install netaddr
