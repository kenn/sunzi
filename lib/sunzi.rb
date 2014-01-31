require 'thor'
require 'rainbow'
require 'rainbow/ext/string'
require 'yaml'

module Sunzi
  autoload :Cli,        'sunzi/cli'
  autoload :Cloud,      'sunzi/cloud'
  autoload :Dependency, 'sunzi/dependency'
  autoload :DNS,        'sunzi/dns'
  autoload :Logger,     'sunzi/logger'
  autoload :Utility,    'sunzi/utility'

  class Cloud
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
