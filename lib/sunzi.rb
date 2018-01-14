# Stdlib
require 'erb'
require 'pathname'
require 'yaml'

# Gems
require 'hashugar'
require 'rainbow/ext/string'
require 'thor'

# Sunzi
module Sunzi
  GemRoot = Pathname.new(Gem.loaded_specs['sunzi'].gem_dir)
end

require 'sunzi/core_ext'
require 'sunzi/actions'
require 'sunzi/dependency'

require 'sunzi/cli'

# Plug-ins
require 'sunzi/plugin'
Sunzi::Plugin.load
