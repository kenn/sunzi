LIB_PATH = File.join(File.dirname(__FILE__), 'sunzi')

module Sunzi
  autoload :Base,       File.join(LIB_PATH, 'base')
  autoload :Cli,        File.join(LIB_PATH, 'cli')
  autoload :Version,    File.join(LIB_PATH, 'version')
end
