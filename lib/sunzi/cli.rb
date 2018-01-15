require 'sunzi/command'

module Sunzi
  class Cli < Thor

    desc 'create', 'Create sunzi project'
    def create(project = 'sunzi')
      Sunzi::Command.new.create(project)
    end

    desc 'deploy [user@host:port] [role] [--sudo]', 'Deploy sunzi project'
    method_options sudo: false
    def deploy(target, role = nil)
      Sunzi::Command.new.deploy(target, role, options)
    end

    desc 'compile', 'Compile sunzi project'
    def compile(role = nil)
      Sunzi::Command.new.compile(role)
    end

    desc 'version', 'Show version'
    def version
      puts Gem.loaded_specs['sunzi'].version.to_s
    end

  end
end
