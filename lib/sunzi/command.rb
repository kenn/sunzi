require 'open3'
require 'sunzi/endpoint'

module Sunzi
  class Command
    include Sunzi::Actions::Delegate

    delegate_to_thor :copy_file, :template, :get, :append_to_file, :options

    def create(project)
      copy_file 'templates/create/.gitignore',         "#{project}/.gitignore"
      copy_file 'templates/create/sunzi.yml',          "#{project}/sunzi.yml"
      copy_file 'templates/create/install.sh',         "#{project}/install.sh"
      copy_file 'templates/create/recipes/sunzi.sh',   "#{project}/recipes/sunzi.sh"
      copy_file 'templates/create/roles/db.sh',        "#{project}/roles/db.sh"
      copy_file 'templates/create/roles/web.sh',       "#{project}/roles/web.sh"
      copy_file 'templates/create/files/.gitkeep',     "#{project}/files/.gitkeep"
    end

    def deploy(first, *args)
      role = args[0]

      sudo = 'sudo ' if options.sudo?
      endpoint = Endpoint.new(first)

      # compile vars and recipes
      compile(role)

      # The host key might change when we instantiate a new VM, so
      # we remove (-R) the old host key from known_hosts.
      `ssh-keygen -R #{endpoint.host} 2> /dev/null`

      remote_commands = <<-EOS
      rm -rf ~/sunzi &&
      mkdir ~/sunzi &&
      cd ~/sunzi &&
      tar xz &&
      #{sudo}bash install.sh
      EOS

      remote_commands.strip! << ' && rm -rf ~/sunzi' if config.preferences.erase_remote_folder

      local_commands = <<-EOS
      cd compiled
      tar cz . | ssh -o 'StrictHostKeyChecking no' #{endpoint.user}@#{endpoint.host} -p #{endpoint.port} '#{remote_commands}'
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

    def compile(role = nil)
      abort_with "#{role} doesn't exist!" if role && !File.exist?("roles/#{role}.sh")
      abort_with 'As of v2, "attributes" are now "vars" in sunzi.yml and shell scripts.' if config.attributes

      # Retrieve remote recipes via HTTP
      (config.recipes || []).each do |key, value|
        dest = "compiled/recipes/#{key}.sh"
        next if config.preferences.cache_remote_recipes && File.exist?(dest)
        get value, dest
      end

      @vars = config.vars # Used within ERB templates

      # Copy local files to compiled folder
      files = Dir['{recipes,roles,files}/**/*'].select { |file| File.file?(file) }

      files.each do |file|
        render file, "compiled/#{file}"
      end

      # Copy files specified in sunzi.yml
      (config.files || []).each do |file|
        render file, "compiled/files/#{File.basename(file)}"
      end

      # Build install.sh
      render 'install.sh', 'compiled/install.sh'

      # Append role at the bottom of install.sh
      if role
        append_to_file 'compiled/install.sh', "\n" + File.read("compiled/roles/#{role}.sh")
      end
    end

  private

    def config
      @config ||= begin
        abort_with 'You must be in a sunzi folder' unless File.exist?('sunzi.yml')

        YAML.load(File.read('sunzi.yml')).to_hashugar
      end
    end

    # template method requires absolute path to work with current directory
    #
    def render(source, target)
      template File.expand_path(source), target, context: binding
    end

  end
end
