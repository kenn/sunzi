require 'thor'
require 'rainbow'
require 'yaml'

module Sunzi
  autoload :Cli,        'sunzi/cli'
  autoload :Dependency, 'sunzi/dependency'
  autoload :Logger,     'sunzi/logger'
  autoload :Utility,    'sunzi/utility'
  autoload :Version,    'sunzi/version'

  module Cloud
    autoload :Base,         'sunzi/cloud/base'
    autoload :Linode,       'sunzi/cloud/linode'
    autoload :EC2,          'sunzi/cloud/ec2'
    autoload :DigitalOcean, 'sunzi/cloud/digital_ocean'
  end
end
