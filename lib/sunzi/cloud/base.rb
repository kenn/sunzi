Sunzi::Dependency.load('highline')

module Sunzi
  class Cloud
    class Base
      include Sunzi::Utility

      def initialize(cli, provider)
        @provider = provider
        @cli = cli
        @ui = HighLine.new
      end

      def setup
        unless File.exist? provider_config_path
          @cli.empty_directory "#{@provider}/instances"
          @cli.template "templates/setup/#{provider_config_path}", provider_config_path
          exit_with "Now go ahead and edit #{@provider}.yml, then run this command again!"
        end

        assign_config_and_dns

        if @config['fqdn']['zone'] == 'example.com'
          abort_with "You must have your own settings in #{@provider}.yml"
        end

        # Ask environment and hostname
        @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('hostname? (only the first part of subdomain): ', String).to_s

        abort_with '"label" field in linode.yml is no longer supported. rename it to "name".' if @config['label']
        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)
        @name = @config['name'][@env].gsub(/%{host}/, @host)
        abort_with "#{@name} already exists!" if instance_config_path.exist?

        assign_api
        @attributes = {}
        do_setup

        # Save instance info
        @cli.create_file instance_config_path, YAML.dump(@instance)

        # Register IP to DNS
        @dns.add(@fqdn, @public_ip) if @dns
      end

      def teardown
        names = Dir.glob("#{@provider}/instances/*.yml").map{|i| i.split('/').last.sub('.yml','') }
        abort_with "No match found with #{@provider}/instances/*.yml" if names.empty?

        names.each{|i| say i }
        @name = ask("which instance?: ", String) {|q| q.in = names }

        assign_config_and_dns

        @instance = YAML.load(instance_config_path.read)

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:fqdn]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Run Linode / DigitalOcean specific tasks
        assign_api
        do_teardown

        # Delete DNS record
        @dns.delete(@instance[ip_key]) if @dns

        # Remove the instance config file
        @cli.remove_file instance_config_path

        say 'Done.'
      end

      def assign_config_and_dns
        @config = YAML.load(provider_config_path.read)
        @dns = Sunzi::DNS.new(@config, @provider) if @config['dns']
      end

      def provider_config_path
        Pathname.new "#{@provider}/#{@provider}.yml"
      end

      def instance_config_path
        Pathname.new "#{@provider}/instances/#{@name}.yml"
      end

      def ask(question, answer_type, &details)
        @ui.ask(@ui.color(question, :green, :bold), answer_type, &details)
      end

      def proceed?
        moveon = ask("Are you ready to go ahead and create #{@fqdn}? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'
      end
    end
  end
end
