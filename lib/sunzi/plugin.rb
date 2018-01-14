module Sunzi
  module Plugin
    class << self
      # Find gems that start with "sunzi-*" and require them automatically.
      # If that gem is a plugin, it will call the register method on load.

      def load
        plugins = Gem::Specification.find_all.select{|plugin| plugin.name =~ /sunzi-.+/ }
        plugins.each do |plugin|
          require plugin.name.gsub('-','/')

          Sunzi.thor.source_paths << Pathname.new(plugin.gem_dir)
        end
      end
    end
  end
end
