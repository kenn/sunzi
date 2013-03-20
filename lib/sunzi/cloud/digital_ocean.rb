Sunzi::Dependency.load('digital_ocean')

module Sunzi
  module Cloud
    class DigitalOcean < Base
      def setup
        unless File.exist? 'digital_ocean/digital_ocean.yml'
          @cli.empty_directory 'digital_ocean/instances'
          @cli.template 'templates/setup/digital_ocean/digital_ocean.yml', 'digital_ocean/digital_ocean.yml'
          exit_with 'Now go ahead and edit digital_ocean.yml, then run this command again!'
        end

        @config = YAML.load(File.read('digital_ocean/digital_ocean.yml'))

        if @config['fqdn'] && @config['fqdn']['zone'] == 'example.com'
          abort_with 'You must have your own settings in digital_ocean.yml'
        end
        # When route53 is specified for DNS, check if it's properly configured and if not, fail earlier.
        setup_route53 if @config['dns'] == 'route53'

        @api = ::DigitalOcean::API.new :api_key => @config['api_key'], :client_id => @config['client_id']

        # Ask environment and hostname
        @env = ask("create for which environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('subdomain name? (leave empty if none): ', String).to_s

        @name = @config['name'][@env]
        if @host.nil? || @host.empty?
          @name = @name.gsub(/\-%{host}/, '')
        else
          @name = @name.gsub(/%{host}/, @host)
        end

        # Choose a size
        result = @api.sizes.list.sizes
        result.each{|i| say "#{i.id}: #{i.name}" }
        @size_id = ask('which size?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @size_name = result.find{|i| i.id == @size_id }.name

        # Choose a region
        result = @api.regions.list.regions
        result.each{|i| say "#{i.id}: #{i.name}" }
        @region_id = ask('which region?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @region_name = result.find{|i| i.id == @region_id }.name

        # Choose a image
        result = @api.images.list({'filter' => 'global'}).images
        if @config['distributions_filter']
          result = result.select{|i| i.distribution.match Regexp.new(@config['distributions_filter'], Regexp::IGNORECASE) }
        end
        result.each{|i| say "#{i.id}: #{i.name}" }
        @image_id = ask('which image?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @image_name = result.find{|i| i.id == @image_id }.name

        # Go ahead?
        moveon = ask("Are you ready to go ahead and create #{@name}? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        @ssh_key_ids = @api.ssh_keys.list.ssh_keys.map(&:id).join(',')

        # Create
        say "creating a new droplets..."
        result = @api.droplets.create(:name => @name,
          :size_id => @size_id,
          :image_id => @image_id,
          :region_id => @region_id,
          :ssh_key_ids => @ssh_key_ids)

        @droplet_id = result.droplet.id
        say "Created a new droplet (id: #{@droplet_id}). Booting..."

        # Boot
        while @api.droplets.show(@droplet_id).droplet.status.downcase != 'active'
          sleep 5
        end

        @public_ip = @api.droplets.show(@droplet_id).droplet.ip_address
        say "Done. ip address = #{@public_ip}"

        # Register IP to DNS
        case @config['dns']
        when 'route53'
          # Set the public IP to AWS Route 53
          say "Setting the public IP to AWS Route 53..."
          Route53::DNSRecord.new(@fqdn, "A", "300", [@public_ip], @route53_zone).create
        end

        # Save the instance info
        hash = {
          :droplet_id => @droplet_id,
          :env => @env,
          :host => @host,
          :fqdn => @fqdn,
          :name => @name,
          :ip_address => @public_ip,
          :size_id => @size_id,
          :size_name => @size_name,
          :region_id => @region_id,
          :region_name => @region_name,
          :image_id => @image_id,
          :image_name => @image_name,
        }
        @cli.create_file "digital_ocean/instances/#{@name}.yml", YAML.dump(hash)

      end

      def teardown(name)
        unless File.exist?("digital_ocean/instances/#{name}.yml")
          abort_with "#{name}.yml was not found in the instances directory."
        end

        @config = YAML.load(File.read('digital_ocean/digital_ocean.yml'))
        setup_route53 if @config['dns'] == 'route53'

        @instance = YAML.load(File.read("digital_ocean/instances/#{name}.yml"))
        @droplet_id = @instance[:droplet_id]

        @api = ::DigitalOcean::API.new :api_key => @config['api_key'], :client_id => @config['client_id']

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:fqdn]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Delete the droplet
        say 'deleting droplet...'
        @api.droplets.delete(@droplet_id)

        # Delete DNS record
        case @config['dns']
        when 'route53'
          say 'deleting the public IP from AWS Route 53...'
          @record = @route53_zone.get_records.find{|i| i.values.first == @instance[:ip_address] }
          @record.delete if @record
        end

        # Remove the instance config file
        @cli.remove_file "digital_ocean/instances/#{name}.yml"

        say 'Done.'
      end

      def setup_route53
        Sunzi::Dependency.load('route53')
        route53 = Route53::Connection.new(@config['route53']['key'], @config['route53']['secret'])
        @route53_zone = route53.get_zones.find{|i| i.name.sub(/\.$/,'') == @config['fqdn']['zone'] }
        abort_with "zone for #{@config['fqdn']['zone']} was not found on route53!" unless @route53_zone
      end
    end
  end
end
