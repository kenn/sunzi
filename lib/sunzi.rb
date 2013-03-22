require 'thor'
require 'rainbow'
require 'yaml'

module Sunzi
  autoload :Cli,        'sunzi/cli'
  autoload :Dependency, 'sunzi/dependency'
  autoload :Logger,     'sunzi/logger'
  autoload :Utility,    'sunzi/utility'

  module Cloud
    autoload :Base,         'sunzi/cloud/base'
    autoload :Linode,       'sunzi/cloud/linode'
    autoload :DigitalOcean, 'sunzi/cloud/digital_ocean'
  end
end
