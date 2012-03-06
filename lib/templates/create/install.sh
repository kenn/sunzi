#!/bin/bash

# Load base utility functions like sunzi::silencer()
source recipes/sunzi.sh

# This line is necessary for automated provisioning for Debian/Ubuntu.
# Remove if you're not on Debian/Ubuntu.
export DEBIAN_FRONTEND=noninteractive

# Add Dotdeb repository. Recommended if you're using Debian. See http://www.dotdeb.org/about/
# source recipes/dotdeb.sh

# SSH key
source recipes/ssh_key.sh $(cat attributes/ssh_key)

# Update apt catalog. If you prefer less verbosity, use the sunzi::silencer version instead
aptitude update
aptitude -y safe-upgrade
# sunzi::silencer "aptitude update"
# sunzi::silencer "aptitude -y safe-upgrade"

# Install packages. If you prefer less verbosity, use the sunzi::silencer version instead
aptitude -y install git-core ntp
# sunzi::silencer "aptitude -y install git-core ntp"
