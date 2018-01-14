module Sunzi
  class Dependency < Struct.new(:name, :version)

    @list = {}

    def initialize(*args)
      super
      self.class.list[name] = self
    end

    class << self
      attr_accessor :list

      def load(key)
        unless dependency = @list[key]
          fail "#{key} is not initialized. Run Sunzi::Dependency.new('#{key}', '~> ...')"
        end

        name, version = dependency.name, dependency.version

        begin
          gem(name, version)
          require(name)
        rescue LoadError
          base = GemRoot.join('templates/dependency')
          which = if $!.to_s =~ /Gemfile/
            'gemfile'
          else
            'install'
          end
          text = ERB.new(base.join("#{which}.erb").read, nil, '-').result(binding)
          abort_with text
        end
      end
    end
  end
end
