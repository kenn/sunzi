Sunzi::Dependency.load('digital_ocean')

module Sunzi
  class Cloud
    class DigitalOcean < Base
      def do_setup
        # Ask environment and hostname
        @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('hostname? (only the first part of subdomain): ', String).to_s

        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)
        @name = @config['name'][@env].gsub(/%{host}/, @host)

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
        moveon = ask("Are you ready to go ahead and create #{@fqdn}? (y/n) ", String) {|q| q.in = ['y','n']}
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
        @dns.add(@fqdn, @public_ip) if @dns

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

      def do_teardown
        say 'deleting droplet...'
        @api.droplets.delete(@instance[:droplet_id])
      end

      def assign_api
        @api = ::DigitalOcean::API.new :api_key => @config['api_key'], :client_id => @config['client_id']
      end

      def ip_key
        :ip_address
      end
    end
  end
end
