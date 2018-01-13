require 'forwardable'

module Sunzi
  class Worker < Thor
    # This class exists because thor has to be inherited AND included to import actions.
    #
    # https://github.com/erikhuda/thor/wiki/Actions
    #
    # This interface is ugly. Instead, initialize once and reuse everywhere.

    include Thor::Actions

    source_root Pathname.new(__FILE__).dirname.parent

    module Delegate
      def self.included(base)
        base.extend Forwardable
        base.extend ClassMethods
      end

      module ClassMethods
        def delegate_to_worker(*args)
          def_delegators :'Sunzi.worker', *args
        end
      end
    end
  end

  class << self
    def worker
      @worker ||= Sunzi::Worker.new
    end
  end
end
