require 'forwardable'

module Sunzi
  class Worker < Thor
    # This class exists because thor has to be inherited AND included to import actions.
    #
    # https://github.com/erikhuda/thor/wiki/Actions
    #
    # This interface is ugly. Instead, initialize once and reuse everywhere.

    include Thor::Actions
    include Sunzi::Utility

    source_root Pathname.new(__FILE__).dirname.parent

    no_commands do
      # non-command methods go here
    end

    module Delegate
      def self.included(base)
        base.extend Forwardable
        base.def_delegators :'Sunzi.worker', :create_file, :copy_file, :template, :abort_with, :get, :append_to_file
      end
    end
  end

  class << self
    def worker
      @worker ||= Sunzi::Worker.new
    end
  end
end
