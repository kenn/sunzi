require 'thor'
require 'rainbow'
require 'yaml'

module Sunzi
  autoload :Cli,        'sunzi/cli'
  autoload :Dependency, 'sunzi/dependency'
  autoload :DNS,        'sunzi/dns'
  autoload :Logger,     'sunzi/logger'
  autoload :Utility,    'sunzi/utility'

  module Cloud
    autoload :Base,         'sunzi/cloud/base'
    autoload :Linode,       'sunzi/cloud/linode'
    autoload :DigitalOcean, 'sunzi/cloud/digital_ocean'
  end

  class DNS
    autoload :Base,     'sunzi/dns/base'
    autoload :Linode,   'sunzi/dns/linode'
    autoload :Route53,  'sunzi/dns/route53'
  end
end
