#!/bin/bash

# This line is necessary for automated provisioning for Debian/Ubuntu
export DEBIAN_FRONTEND=noninteractive

# SSH key
source recipes/ssh_key.sh $(cat attributes/ssh_key)

# Add Dotdeb repository
source recipes/dotdeb.sh

# Update apt catalog
aptitude update
aptitude -y safe-upgrade
