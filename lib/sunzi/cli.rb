require 'thor'
require 'yaml'
require 'fileutils'
require 'open3'

module Sunzi
  CONFIG_DIR = File.join(ENV['HOME'],'.config','sunzi')

  class Cli < Thor
    include Thor::Actions

    class << self
      def source_root
        File.expand_path('../../',__FILE__)
      end
    end

    # map "cr" => :create
    # map "d" => :deploy

    desc "create [PROJECT]", "Create sunzi project"
    def create(project = 'sunzi')
      empty_directory project
      empty_directory "#{project}/remote"
      empty_directory "#{project}/remote/recipes"
      template "templates/attributes.yml",            "#{project}/attributes.yml"
      template "templates/recipes.yml",               "#{project}/recipes.yml"
      template "templates/remote/install.sh",         "#{project}/remote/install.sh"
      template "templates/remote/recipes/ssh_key.sh", "#{project}/remote/recipes/ssh_key.sh"
    end

    desc "deploy [USER@HOST] [PORT]", "Deploy sunzi project"
    def deploy(*target)
      if target.empty? or !target.first.match(/@/)
        say shell.set_color("Usage: sunzi deploy root@example.com", :red, true)
        abort
      end

      compile

      host, port = target
      port ||= 22
      user, domain = host.split('@')

      commands = <<-EOS
      ssh-keygen -R #{domain}
      cd remote
      tar cz . | ssh -o 'StrictHostKeyChecking no' #{host} -p #{port} '
      rm -rf ~/sunzi &&
      mkdir ~/sunzi &&
      cd ~/sunzi &&
      tar xz &&
      bash install.sh'
      EOS

      Open3.popen3(commands) do |stdin, stdout, stderr|
        stdin.close
        t = Thread.new(stderr) do |terr|
          while (line = terr.gets)
            print "\e[31m#{line}\e[0m"
          end
        end
        while (line = stdout.gets)
          print "\e[32m#{line}\e[0m"
        end
        t.join
      end
    end

    desc "compile", "Compile sunzi project"
    def compile
      # Check if you're in the sunzi directory
      unless File.exists?('attributes.yml')
        say shell.set_color("You must be in the sunzi folder", :red, true)
        abort
      end

      # Compile attributes.yml
      hash = YAML.load(File.read('attributes.yml'))
      empty_directory 'remote/attributes'
      hash.each do |key, value|
        File.open("remote/attributes/#{key}", 'w'){|file| file.write(value) }
      end

      # Compile recipes.yml
      hash = YAML.load(File.read('recipes.yml'))
      empty_directory 'remote/recipes'
      hash.each do |key, value|
        get value, "remote/recipes/#{key}.sh"
      end
    end
  end
end
