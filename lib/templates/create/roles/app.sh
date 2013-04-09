# Install Application Server

# Required attributes: env, ruby_version
export ENVIRONMENT=$(cat attributes/environment)
export RUBY_VERSION=$(cat attributes/ruby_version)

# Install RVM
source recipes/rvm.sh

# Set RAILS_ENV
if grep -Fq "RAILS_ENV" ~/.bash_profile; then
  echo 'RAILS_ENV entry already exists'
else
  echo "export RAILS_ENV=$ENVIRONMENT" >> ~/.bash_profile
  source ~/.bash_profile
fi

# Install Ruby
if [[ "$(which ruby)" == /usr/local/rvm/rubies/ruby-$RUBY_VERSION* ]]; then
  echo 'ruby-$RUBY_VERSION already installed'
else
  apt-get -y install curl build-essential libssl-dev libreadline6-dev
  rvm install $RUBY_VERSION
  rvm $RUBY_VERSION --default
  echo 'gem: --no-ri --no-rdoc' > ~/.gemrc

  # Install RubyGems
  gem update --system
  gem install bundler
fi
