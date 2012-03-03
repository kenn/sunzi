require 'open3'

module Sunzi
  class Cli < Thor
    include Thor::Actions

    desc "create", "Create sunzi project"
    def create(project = 'sunzi')
      do_create(project)
    end

    desc "deploy [user@host:port] [role]", "Deploy sunzi project"
    def deploy(target, role = nil)
      do_deploy(target, role)
    end

    desc "compile", "Compile sunzi project"
    def compile
      do_compile
    end

    desc "setup [linode|ec2]", "Setup a new VM"
    def setup(target)
      Cloud::Base.choose(self, target).setup
    end

    desc "teardown [linode|ec2] [name]", "Teardown an existing VM"
    def teardown(target, name)
      Cloud::Base.choose(self, target).teardown(name)
    end

    no_tasks do
      include Sunzi::Utility

      def self.source_root
        File.expand_path('../../',__FILE__)
      end

      def do_create(project)
        empty_directory project
        empty_directory "#{project}/recipes"
        empty_directory "#{project}/roles"
        template "templates/create/.gitignore",         "#{project}/.gitignore"
        template "templates/create/sunzi.yml",          "#{project}/sunzi.yml"
        template "templates/create/install.sh",         "#{project}/install.sh"
        template "templates/create/recipes/ssh_key.sh", "#{project}/recipes/ssh_key.sh"
        template "templates/create/roles/app.sh",       "#{project}/roles/app.sh"
        template "templates/create/roles/db.sh",        "#{project}/roles/db.sh"
        template "templates/create/roles/web.sh",       "#{project}/roles/web.sh"
      end

      def do_deploy(target, role)
        user, host, port = parse_target(target)
        endpoint = "#{user}@#{host}"

        # Check if role exists
        abort_with "#{role} doesn't exist!" if role and !File.exists?("roles/#{role}.sh")

        # compile attributes and recipes
        compile

        # The host key might change when we instantiate a new VM, so
        # we remove (-R) the old host key from known_hosts.
        `ssh-keygen -R #{host} 2> /dev/null`

        remote_commands = <<-EOS
        rm -rf ~/sunzi &&
        mkdir ~/sunzi &&
        cd ~/sunzi &&
        tar xz &&
        bash install.sh &&
        EOS

        # Append role-based scripts
        remote_commands << (role ? "bash roles/#{role}.sh" : 'echo "no role specified"')

        local_commands = <<-EOS
        cd compiled
        tar cz . | ssh -o 'StrictHostKeyChecking no' #{endpoint} -p #{port} '#{remote_commands}'
        EOS

        Open3.popen3(local_commands) do |stdin, stdout, stderr|
          stdin.close
          t = Thread.new do
            while (line = stderr.gets)
              print line.color(:red).bright
            end
          end
          while (line = stdout.gets)
            print line.color(:green).bright
          end
          t.join
        end
      end

      def do_compile
        # Check if you're in the sunzi directory
        abort_with "You must be in the sunzi folder" unless File.exists?('sunzi.yml')

        # Load sunzi.yml
        hash = YAML.load(File.read('sunzi.yml'))
        empty_directory 'compiled'
        empty_directory 'compiled/attributes'
        empty_directory 'compiled/recipes'
        empty_directory 'compiled/files'

        # Break down attributes into individual files
        hash['attributes'].each do |key, value|
          create_file "compiled/attributes/#{key}", value
        end

        # Retrieve remote recipes via HTTP
        hash['recipes'].each do |key, value|
          get value, "compiled/recipes/#{key}.sh"
        end

        # Copy local recipes
        Dir['recipes/*'].each do |file|
          copy_file File.expand_path(file), "compiled/recipes/#{File.basename(file)}"
        end

        # Copy roles
        Dir['roles/*'].each do |file|
          copy_file File.expand_path(file), "compiled/roles/#{File.basename(file)}"
        end

        # Copy files
        hash['files'].each do |file|
          copy_file File.expand_path(file), "compiled/files/#{File.basename(file)}"
        end

        copy_file File.expand_path('install.sh'), 'compiled/install.sh'
      end

      def parse_target(target)
        target.match(/(.*@)?(.*?)(:.*)?$/)
        [ ($1 && $1.delete('@') || 'root'), $2, ($3 && $3.delete(':') || '22') ]
      end
    end
  end
end
