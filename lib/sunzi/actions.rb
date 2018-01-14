require 'forwardable'

module Sunzi
  class Actions < Thor
    # This class exists because thor has to be inherited AND included to import actions.
    #
    # https://github.com/erikhuda/thor/wiki/Actions
    #
    # This interface is ugly. Instead, initialize once and reuse everywhere.

    include Thor::Actions

    source_root GemRoot

    # include this module to use delegate_to_thor method.
    module Delegate
      def self.included(base)
        base.extend Forwardable
        base.extend ClassMethods
      end

      module ClassMethods
        def delegate_to_thor(*args)
          def_delegators :'Sunzi.thor', *args
        end
      end
    end
  end

  class << self
    def thor
      @thor ||= Sunzi::Actions.new
    end
  end
end
