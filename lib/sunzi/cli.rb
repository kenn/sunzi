require 'open3'

module Sunzi
  class Cli < Thor
    include Thor::Actions

    desc "create", "Create sunzi project"
    def create(project = 'sunzi')
      do_create(project)
    end

    desc "deploy [user@host:port] [role] [--sudo]", "Deploy sunzi project"
    method_options :sudo => false
    def deploy(target, role = nil)
      do_deploy(target, role, options.sudo?)
    end

    desc "compile", "Compile sunzi project"
    def compile(role = nil)
      do_compile(role)
    end

    desc "setup [openstack|linode|ec2]", "Setup a new VM"
    def setup(target)
      Cloud::Base.choose(self, target).setup
    end

    desc "teardown [openstack|linode|ec2] [name]", "Teardown an existing VM"
    def teardown(target, name)
      Cloud::Base.choose(self, target).teardown(name)
    end

    no_tasks do
      include Sunzi::Utility

      def self.source_root
        File.expand_path('../../',__FILE__)
      end

      def do_create(project)
        template "templates/create/.gitignore",         "#{project}/.gitignore"
        template "templates/create/sunzi.yml",          "#{project}/sunzi.yml"
        template "templates/create/install.sh",         "#{project}/install.sh"
        template "templates/create/recipes/sunzi.sh",   "#{project}/recipes/sunzi.sh"
        template "templates/create/recipes/ssh_key.sh", "#{project}/recipes/ssh_key.sh"
        template "templates/create/roles/app.sh",       "#{project}/roles/app.sh"
        template "templates/create/roles/db.sh",        "#{project}/roles/db.sh"
        template "templates/create/roles/web.sh",       "#{project}/roles/web.sh"
      end

      def do_deploy(target, role, force_sudo)
        sudo = 'sudo ' if force_sudo
        user, host, port = parse_target(target)
        endpoint = "#{user}@#{host}"

        # compile attributes and recipes
        do_compile(role)

        # The host key might change when we instantiate a new VM, so
        # we remove (-R) the old host key from known_hosts.
        `ssh-keygen -R #{host} 2> /dev/null`

        remote_commands = <<-EOS
        rm -rf ~/sunzi &&
        mkdir ~/sunzi &&
        cd ~/sunzi &&
        tar xz &&
        #{sudo}bash install.sh
        EOS

        remote_commands.strip! << ' && rm -rf ~/sunzi' if @config['preferences'] and @config['preferences']['erase_remote_folder']

        ssh_args = ""
        ssh_args << "-i #{@config['preferences']['ssh_key']}" if @config['preferences']['ssh_key']
        local_commands = <<-EOS
        cd compiled
        tar cz . | ssh -o 'StrictHostKeyChecking no' #{ssh_args} #{endpoint} -p #{port} '#{remote_commands}'
        EOS

        Open3.popen3(local_commands) do |stdin, stdout, stderr|
          stdin.close
          t = Thread.new do
            while (line = stderr.gets)
              print line.color(:red)
            end
          end
          while (line = stdout.gets)
            print line.color(:green)
          end
          t.join
        end
      end

      def do_compile(role)
        # Check if you're in the sunzi directory
        abort_with "You must be in the sunzi folder" unless File.exists?('sunzi.yml')
        # Check if role exists
        abort_with "#{role} doesn't exist!" if role and !File.exists?("roles/#{role}.sh")

        # Load sunzi.yml
        @config = YAML.load(File.read('sunzi.yml'))

        # Break down attributes into individual files
        (@config['attributes'] || []).each {|key, value| create_file "compiled/attributes/#{key}", value }

        # Retrieve remote recipes via HTTP
        cache_remote_recipes = @config['preferences'] && @config['preferences']['cache_remote_recipes']
        (@config['recipes'] || []).each do |key, value|
          next if cache_remote_recipes and File.exists?("compiled/recipes/#{key}.sh")
          get value, "compiled/recipes/#{key}.sh"
        end

        # Copy local files
        Dir['recipes/*'].each         {|file| copy_file File.expand_path(file), "compiled/recipes/#{File.basename(file)}" }
        Dir['roles/*'].each           {|file| copy_file File.expand_path(file), "compiled/roles/#{File.basename(file)}" }
        (@config['files'] || []).each {|file| copy_file File.expand_path(file), "compiled/files/#{File.basename(file)}" }

        # Build install.sh
        if role
          create_file 'compiled/install.sh', File.binread("install.sh") << "\n" << File.binread("roles/#{role}.sh")
        else
          copy_file File.expand_path('install.sh'), 'compiled/install.sh'
        end
      end

      def parse_target(target)
        target.match(/(.*@)?(.*?)(:.*)?$/)
        [ ($1 && $1.delete('@') || 'root'), $2, ($3 && $3.delete(':') || '22') ]
      end
    end
  end
end
