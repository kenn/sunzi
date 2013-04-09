#!/bin/bash

# Load base utility functions like sunzi.mute() and sunzi.install()
source recipes/sunzi.sh

# This line is necessary for automated provisioning for Debian/Ubuntu.
# Remove if you're not on Debian/Ubuntu.
export DEBIAN_FRONTEND=noninteractive

# Add Dotdeb repository. Recommended if you're using Debian. See http://www.dotdeb.org/about/
# source recipes/dotdeb.sh

# Update installed packages
sunzi.mute "apt-get update"
sunzi.mute "apt-get -y upgrade"

# Install packages
sunzi.install "git-core ntp curl"

# Set RAILS_ENV
environment=$(cat attributes/environment)

if ! grep -Fq "RAILS_ENV" ~/.bash_profile; then
  echo 'Setting up RAILS_ENV...'
  echo "export RAILS_ENV=$environment" >> ~/.bash_profile
  source ~/.bash_profile
fi

# Install Ruby using RVM
source recipes/rvm.sh
ruby_version=$(cat attributes/ruby_version)

if [[ "$(which ruby)" != /usr/local/rvm/rubies/ruby-$ruby_version* ]]; then
  echo "Installing ruby-$ruby_version"
  sunzi.install build-essential libssl-dev libreadline6-dev
  rvm install $ruby_version
  rvm $ruby_version --default
  echo 'gem: --no-ri --no-rdoc' > ~/.gemrc

  # Install Bundler
  gem update --system
  gem install bundler
fi

# Install sysstat, then configure if this is a new install.
if sunzi.install "sysstat"; then
  sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
  /etc/init.d/sysstat restart
fi
