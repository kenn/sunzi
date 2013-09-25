require 'open3'
require 'ostruct'
require 'net/ssh'

module Sunzi
  class Cli < Thor
    include Thor::Actions

    desc 'create', 'Create sunzi project'
    def create(project = 'sunzi')
      do_create(project)
    end

    desc 'provision [user@host:port] [role] [--sudo]', 'Provision server with sunzi'
    method_options :sudo => false
    def provision(target, role = nil)
      do_deploy(target, role, options.sudo?)
    end
    desc 'deploy [user@host:port] [role] [--sudo]', 'Deprecated: use provision instead'
    alias_method :deploy, :provision

    desc 'compile', 'Compile sunzi project'
    def compile(role = nil)
      do_compile(role)
    end

    desc 'setup [linode|digital_ocean]', 'Setup a new VM'
    def setup(provider)
      Sunzi::Cloud.new(self, provider).setup
    end

    desc 'teardown [linode|digital_ocean] [name]', 'Teardown an existing VM'
    def teardown(provider, name)
      Sunzi::Cloud.new(self, provider).teardown(name)
    end

    desc 'version', 'Show version'
    def version
      puts Gem.loaded_specs['sunzi'].version.to_s
    end

    desc 'recipe [NAME]', 'Generate a recipe'
    def recipe(name, project = 'sunzi')
      file_name = [Time.now.strftime("%Y%m%d%H%M%S"), name].join("-") + ".sh"
      directory = File.join(project, "recipes")
      if File.exist? directory
        file_path = File.join(directory, file_name)
        create_file file_path
      else
        puts "Sunzi directory structure not present. Run [create] first."
      end
    end

    no_tasks do
      include Sunzi::Utility

      def self.source_root
        File.expand_path('../../',__FILE__)
      end

      def do_create(project)
        copy_file 'templates/create/.gitignore',         "#{project}/.gitignore"
        copy_file 'templates/create/sunzi.yml',          "#{project}/sunzi.yml"
        copy_file 'templates/create/install.sh',         "#{project}/install.sh"
        copy_file 'templates/create/recipes/sunzi.sh',   "#{project}/recipes/sunzi.sh"
        copy_file 'templates/create/roles/db.sh',        "#{project}/roles/db.sh"
        copy_file 'templates/create/roles/web.sh',       "#{project}/roles/web.sh"
        copy_file 'templates/create/files/.gitkeep',     "#{project}/files/.gitkeep"
      end

      def do_deploy(target, role, force_sudo)
        sudo = 'sudo -E ' if force_sudo
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

        local_commands = <<-EOS
        cd compiled
        tar cz . | ssh -o 'StrictHostKeyChecking no' #{endpoint} -p #{port} '#{remote_commands}'
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
        abort_with 'You must be in the sunzi folder' unless File.exists?('sunzi.yml')
        # Check if role exists
        abort_with "#{role} doesn't exist!" if role and !File.exists?("roles/#{role}.sh")

        # Load sunzi.yml
        @config = YAML.load(File.read('sunzi.yml'))

        # Break down attributes into individual files
        (@config['attributes'] || {}).each {|key, value| create_file "compiled/attributes/#{key}", value }

        # Retrieve remote recipes via HTTP
        cache_remote_recipes = @config['preferences'] && @config['preferences']['cache_remote_recipes']
        (@config['recipes'] || []).each do |key, value|
          next if cache_remote_recipes and File.exists?("compiled/recipes/#{key}.sh")
          get value, "compiled/recipes/#{key}.sh"
        end

        # Copy local files
        @attributes = OpenStruct.new(@config['attributes'])
        copy_or_template = (@config['preferences'] && @config['preferences']['eval_erb']) ? :template : :copy_file
        Dir['recipes/*'].each {|file| send copy_or_template, File.expand_path(file), "compiled/recipes/#{File.basename(file)}" }
        Dir['roles/*'].each   {|file| send copy_or_template, File.expand_path(file), "compiled/roles/#{File.basename(file)}" }
        Dir['files/*'].each   {|file| send copy_or_template, File.expand_path(file), "compiled/files/#{File.basename(file)}" }
        (@config['files'] || []).each {|file| send copy_or_template, File.expand_path(file), "compiled/files/#{File.basename(file)}" }

        # Build install.sh
        if role
          if copy_or_template == :template
            template File.expand_path('install.sh'), 'compiled/_install.sh'
            create_file 'compiled/install.sh', File.binread('compiled/_install.sh') << "\n" << File.binread("compiled/roles/#{role}.sh")
          else
            create_file 'compiled/install.sh', File.binread('install.sh') << "\n" << File.binread("roles/#{role}.sh")
          end
        else
          send copy_or_template, File.expand_path('install.sh'), 'compiled/install.sh'
        end
      end

      def parse_target(target)
        target.match(/(.*@)?(.*?)(:.*)?$/)
        # Load ssh config if it exists
        config = Net::SSH::Config.for($2)
        [ ($1 && $1.delete('@') || config[:user] || 'root'), 
          config[:host_name] || $2, 
          ($3 && $3.delete(':') || config[:port] && config[:port].to_s || '22') ]
      end
    end
  end
end
