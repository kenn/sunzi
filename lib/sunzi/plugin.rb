module Sunzi
  module Plugin
    class << self
      # Find gems that start with "sunzi-*" and require them automatically.
      # If that gem is a plugin, it will call the register method on load.

      def load
        plugins = Gem::Specification.find_all.map(&:name).select{|name| name =~ /sunzi-.+/ }
        plugins.each{|plugin| require plugin.gsub('-','/') }
      end
    end
  end
end
