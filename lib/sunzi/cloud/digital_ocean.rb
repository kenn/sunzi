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

        if @config['fqdn']['zone'] == 'example.com'
          abort_with 'You must have your own settings in digital_ocean.yml'
        end

        # When route53 is specified for DNS, check if it's properly configured and if not, fail earlier.
        setup_route53 if @config['dns'] == 'route53'
        abort_with 'Linode DNS cannot use it. You must have your route53 settings in digital_ocean.yml' unless @config['dns'] == 'route53'

        @sshkey = File.read(File.expand_path(@config['root_sshkey_path'])).chomp
        if @sshkey.match(/\n/)
          abort_with "RootSSHKey #{@sshkey.inspect} must not be multi-line! Check inside \"#{@config['root_sshkey_path']}\""
        end
        @ssh_key_name = @sshkey.split.last

        @api = ::DigitalOcean::API.new :api_key => @config['api_key'], :client_id => @config['client_id']
        say "searching your ssh key..."
        keys = @api.ssh_keys.list.ssh_keys
        found = false unless keys.count > 0
        keys.each do |key|
          found = key if key.name == @ssh_key_name
        end
        abort_with "RootSSHKey cannot found. please setting up your ssh key on DigitalOcean Dashboards.\nname: #{@ssh_key_name}\ndescription:\n#{@sshkey}" unless found
        say "your ssh key found."

        # Ask environment and hostname
        @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('hostname? (only the last part of subdomain): ', String).to_s

        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)


        # Choose a size
        result = @api.sizes.list.sizes
        result.each{|i| say "#{i.id}: #{i.name}" }
        @sizeid = ask('which size?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @size_name = result.find{|i| i.id == @sizeid }.name

        # Choose a region
        result = @api.regions.list.regions
        result.each{|i| say "#{i.id}: #{i.name}" }
        @regionid = ask('which region?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @region_location = result.find{|i| i.id == @regionid }.name

        # Choose a image
        result = @api.images.list({'filter' => 'global'}).images
        if @config['distributions_filter']
          result = result.select{|i| i.distribution.match Regexp.new(@config['distributions_filter'], Regexp::IGNORECASE) }
        end
        result.each{|i| say "#{i.id}: #{i.name}" }
        @imageid = ask('which image?: ', Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @image_name = result.find{|i| i.id == @imageid }.name

        # Go ahead?
        moveon = ask("Are you ready to go ahead and create #{@fqdn}? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Search SSH Key
        say "re-saerching a ssh key..."
        keys = @api.ssh_keys.list.ssh_keys
        found = false unless keys.count > 0
        keys.each do |key|
          found = key if key.name == @ssh_key_name
        end

        if found
          found_key = @api.ssh_keys.show(found.id)
          unless found_key.ssh_key.ssh_pub_key == @sshkey
            abort_with "sshkey found, but different keys. please check it on your DigitalOcean's Dashboards"
          end
        else
          abort_with "sshkey does not found. please check it on your DigitalOcean's Dashboards"
        end


        # Create
        say "creating a new droplets..."
        result = @api.droplets.create(:name => @fqdn, :size_id => @sizeid, :image_id => @imageid, :region_id => @regionid, :ssh_key_ids => found.id)

        @dropletid = result.droplet.id
        say "created a new instance: droplet id = #{@dropletid}"

        # Boot
        say 'Done. Wait for Booting...'
        while @api.droplets.show(@dropletid).droplet.status.downcase != 'active'
          sleep 5
        end
        say 'Booting.'

        @public_ip = @api.droplets.show(@dropletid).droplet.ip_address
        say "fetch public ip address: ip address = #{@public_ip}"

        # Register IP to DNS
        case @config['dns']
        when 'linode'
          abort_with 'Linode DNS cannot use it. You must have your route53 settings in digital_ocean.yml'
        when 'route53'
          # Set the public IP to AWS Route 53
          say "Setting the public IP to AWS Route 53..."
          Route53::DNSRecord.new(@fqdn, "A", "300", [@public_ip], @route53_zone).create
        end

        # Save the instance info
        hash = {
          :dropletid => @dropletid,
          :env => @env,
          :host => @host,
          :fqdn => @fqdn,
          :ip_address => @public_ip,
          :sizeid => @sizeid,
          :redionid => @regionid,
          :region_location => @region_location,
          :imageid => @imageid,
          :image_name => @image_name,
        }
        @cli.create_file "digital_ocean/instances/#{@host}.yml", YAML.dump(hash)

      end

      def teardown(name)
        unless File.exist?("digital_ocean/instances/#{name}.yml")
          abort_with "#{name}.yml was not found in the instances directory."
        end

        @config = YAML.load(File.read('digital_ocean/digital_ocean.yml'))
        setup_route53 if @config['dns'] == 'route53'

        @instance = YAML.load(File.read("digital_ocean/instances/#{name}.yml"))
        @droplet_id = @instance[:dropletid]

        @api = ::DigitalOcean::API.new :api_key => @config['api_key'], :client_id => @config['client_id']

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:fqdn]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'


        say 'deleting droplet...'
        @api.droplets.delete(@droplet_id)

        # Delete DNS record
        case @config['dns']
        when 'linode'
          abort_with 'Linode DNS cannot use it. You must have your route53 settings in digital_ocean.yml'
        when 'route53'
          # Set the public IP to AWS Route 53
          say "deleting the public IP to AWS Route 53..."
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
      end
    end
  end
end
