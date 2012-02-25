require 'thor'

module Sunzi
  CONFIG_DIR = File.join(ENV['HOME'],'.config','sunzi')

  class Cli < Thor
    include Thor::Actions

    class << self
      def source_root
        File.expand_path('../../',__FILE__)
      end
    end

    map "c" => :create

    desc "create [PROJECT]", "Create sunzi project (Shortcut: c)"
    def create(project = 'sunzi')
      empty_directory project
      empty_directory "#{project}/here"
      empty_directory "#{project}/there"
      empty_directory "#{project}/there/recipes"
      template "templates/here/attributes.yml",       "#{project}/here/attributes.yml"
      template "templates/here/compile.rb",           "#{project}/here/compile.rb"
      template "templates/here/deploy.sh",            "#{project}/here/deploy.sh"
      template "templates/there/install.sh",          "#{project}/there/install.sh"
      template "templates/there/recipes/ssh_key.sh",  "#{project}/there/recipes/ssh_key.sh"
    end
  end
end
