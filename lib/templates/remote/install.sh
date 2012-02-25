#!/bin/bash

# This line is necessary for automated provisioning for Debian/Ubuntu
export DEBIAN_FRONTEND=noninteractive

# SSH key
source recipes/ssh_key.sh $(cat attributes/ssh_key)

# Update apt catalog
aptitude update
aptitude -y safe-upgrade

# Install RVM - rvm.sh will be retrieved from Github in the compile phase
source recipes/rvm.sh
