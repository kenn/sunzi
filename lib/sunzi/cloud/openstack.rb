Sunzi::Dependency.load('fog')

YAML::ENGINE.yamler = 'syck'

module Sunzi
  module Cloud
    class OpenStack < Base
      def setup
        # Only run for the first time
        unless File.exist? 'openstack/openstack.yml'
          @cli.empty_directory 'openstack/instances'
          @cli.template 'templates/setup/openstack/openstack.yml', 'openstack/openstack.yml'
          exit_with 'Now go ahead and edit openstack.yml, then run this command again!'
        end

        @config = YAML.load(File.read('openstack/openstack.yml'))

        # Ask environment and hostname
        @env = ask("environment? (*#{@config['environments'].join(' / ')}) ", String) {|q| q.in = @config['environments']; q.default = @config['environments'].first }.to_s
        @env = @config['environments'].first unless (@env and !@env.empty?)

        time_now = Time.now.strftime '%Y%m%d-%H%M%S'
        @host = ask("hostname? (default: #{time_now}) ", String).to_s
        @host = time_now unless (@host and !@host.empty?)

        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)
        @label = @config['label'][@env].gsub(/%{host}/, @host)
        @group = @config['group'][@env]

        say "authenticating..."
        @api = Fog::Compute.new({
          :provider => 'OpenStack',
          :openstack_api_key => @config['api_key'],
          :openstack_username => @config['openstack_username'],
          :openstack_tenant => @config['openstack_tenant'],
          :openstack_auth_url => @config['openstack_auth_url']
        })

        flavor = @api.flavors.find { |f| f.name == @config['image_flavor'] }
        say "selecting flavor #{flavor.name}..."
        image = @api.images.find { |i| i.name =~ /#{@config['image_filter']}/ }
        say "selecting image #{image.name}..."
        if image.nil?
          exit_with "Image #{@config['image_filter']} not found."
        end

        server_name = @label
        say "creating server #{server_name}..."
        server_settings = {
          :name => "#{server_name}",
          :image_ref => image.id,
          :flavor_ref => flavor.id,
        }

        if @config['ssh_key_name']
          server_settings[:key_name] = @config['ssh_key_name']
        end
        server = @api.servers.create server_settings

        say 'done. booting...'
        server.wait_for { ready? }
        say 'creating Public IP...'
        ip = @api.addresses.create
        say "associating Public IP #{ip.ip}..."
        ip.server = server

        # Save the instance info
        hash = {
          :server_id => server.id,
          :name => server.name,
          :env => @env,
          :image => image.name,
          :flavor => flavor.name,
          :public_ip => ip.ip,
          :private_ip => ip.ip,
        }
        @cli.create_file "openstack/instances/#{server_name}.yml", YAML.dump(hash)
      end

      def teardown(name)
        unless File.exist?("openstack/instances/#{name}.yml")
          abort_with "#{name}.yml was not found in the instances directory."
        end
        @config = YAML.load(File.read('openstack/openstack.yml'))
        
        @instance = YAML.load(File.read("openstack/instances/#{name}.yml"))
        @server_id = @instance[:server_id]

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:name]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'
        
        say "authenticating..."
        @api = Fog::Compute.new({
          :provider => 'OpenStack',
          :openstack_api_key => @config['api_key'],
          :openstack_username => @config['openstack_username'],
          :openstack_tenant => @config['openstack_tenant'],
          :openstack_auth_url => @config['openstack_auth_url']
        })

        # Shutdown first or disk deletion will fail
        say 'deleting server...'
        server = @api.servers.find { |s| s.id == @server_id }
        server.destroy

        @cli.remove_file "openstack/instances/#{name}.yml"

        say 'done.'
      end

    end
  end
end
