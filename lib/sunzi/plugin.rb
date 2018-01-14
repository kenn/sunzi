module Sunzi
  module Plugin
    class << self
      # Find gems that start with "sunzi-*" and require them automatically.

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
