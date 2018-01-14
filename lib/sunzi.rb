# Stdlib
require 'erb'
require 'pathname'
require 'yaml'

# Gems
require 'hashugar'
require 'rainbow/ext/string'
require 'thor'

# Sunzi
require 'sunzi/core_ext'
require 'sunzi/actions'
require 'sunzi/dependency'

require 'sunzi/cli'

# Plug-ins
require 'sunzi/plugin'
Sunzi::Plugin.load
