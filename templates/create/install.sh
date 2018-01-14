#!/bin/bash

# Load base utility functions like sunzi.mute() and sunzi.install()
source recipes/sunzi.sh

# This line is necessary for automated provisioning for Debian/Ubuntu.
# Remove if you're not on Debian/Ubuntu.
export DEBIAN_FRONTEND=noninteractive

# Import initial SSH keys from Github
if [ -f ~/.ssh/authorized_keys ]; then
  echo 'authorized_keys already exists'
else
  mkdir -p ~/.ssh
  wget -O - https://github.com/<%= @vars.github_username %>.keys > ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
fi

# Update apt catalog and upgrade installed packages
sunzi.mute "apt-get update"
sunzi.mute "apt-get -y upgrade"

# Install packages
apt-get -y install git-core ntp curl

# Install sysstat, then configure if this is a new install.
if sunzi.install "sysstat"; then
  sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
  /etc/init.d/sysstat restart
fi

# Set RAILS_ENV
environment=<%= @vars.environment %>

if ! grep -Fq "RAILS_ENV" ~/.bash_profile; then
  echo 'Setting up RAILS_ENV...'
  echo "export RAILS_ENV=$environment" >> ~/.bash_profile
  source ~/.bash_profile
fi

# Install RVM using RVM recipe
source recipes/rvm.sh

# Install Ruby
ruby_version=<%= @vars.ruby_version %>

if [[ "$(which ruby)" != /usr/local/rvm/rubies/ruby-$ruby_version* ]]; then
  echo "Installing ruby-$ruby_version"
  # Install dependencies using RVM autolibs - see https://blog.engineyard.com/2013/rvm-ruby-2-0
  rvm install --autolibs=3 $ruby_version
  rvm $ruby_version --default
  echo 'gem: --no-ri --no-rdoc' > ~/.gemrc

  # Install Bundler
  gem install bundler
fi
