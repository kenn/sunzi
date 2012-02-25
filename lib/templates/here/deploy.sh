#!/bin/bash

# Usage: bash deploy.sh [host] [-p 2222]

if [ -z "$1" ]; then
  echo "Usage: bash deploy.sh user@example.com"
  exit 1
fi

# Compile attributes
ruby compile.rb

# The host key might change when we instantiate a new VM, so
# we remove (-R) the old host key from known_hosts
host="$1"
ssh-keygen -R "${host#*@}" 2> /dev/null

# Connect to the remote server and deploy
cd ../there
tar cz . | ssh -o 'StrictHostKeyChecking no' "$host" "$2" "$3" '
rm -rf ~/sunzi &&
mkdir ~/sunzi &&
cd ~/sunzi &&
tar xz &&
bash install.sh'
