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
        unless File.exist? "#{@provider}/#{@provider}.yml"
          @cli.empty_directory "#{@provider}/instances"
          @cli.template "templates/setup/#{@provider}/#{@provider}.yml", "#{@provider}/#{@provider}.yml"
          exit_with "Now go ahead and edit #{@provider}.yml, then run this command again!"
        end

        @config = YAML.load(File.read("#{@provider}/#{@provider}.yml"))
        @dns = Sunzi::DNS.new(@config, @provider) if @config['dns']

        if @config['fqdn']['zone'] == 'example.com'
          abort_with "You must have your own settings in #{@provider}.yml"
        end

        # Ask environment and hostname
        @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('hostname? (only the first part of subdomain): ', String).to_s

        abort_with '"label" field in linode.yml is no longer supported. rename it to "name".' if @config['label']
        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)
        @name = @config['name'][@env].gsub(/%{host}/, @host)

        assign_api
        @attributes = {}
        do_setup

        # Save instance info
        @cli.create_file "#{@provider}/instances/#{@name}.yml", YAML.dump(@instance)

        # Register IP to DNS
        @dns.add(@fqdn, @public_ip) if @dns
      end

      def teardown(name)
        unless File.exist?("#{@provider}/instances/#{name}.yml")
          abort_with "#{name}.yml was not found in the instances directory."
        end

        @config = YAML.load(File.read("#{@provider}/#{@provider}.yml"))
        @dns = Sunzi::DNS.new(@config, @provider) if @config['dns']

        @instance = YAML.load(File.read("#{@provider}/instances/#{name}.yml"))

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:fqdn]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Run Linode / DigitalOcean specific tasks
        assign_api
        do_teardown

        # Delete DNS record
        @dns.delete(@instance[ip_key]) if @dns

        # Remove the instance config file
        @cli.remove_file "#{@provider}/instances/#{name}.yml"

        say 'Done.'
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
