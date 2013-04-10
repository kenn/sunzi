Sunzi::Dependency.load('digital_ocean')

module Sunzi
  class Cloud
    class DigitalOcean < Base
      def do_setup
        choose(:size, @api.sizes.list.sizes)
        choose(:region, @api.regions.list.regions)

        # Choose an image
        result = @api.images.list({'filter' => 'global'}).images
        if @config['distributions_filter']
          result = result.select{|i| i.distribution.match Regexp.new(@config['distributions_filter'], Regexp::IGNORECASE) }
        end
        choose(:image, result)

        # Go ahead?
        proceed?

        ssh_key_ids = @api.ssh_keys.list.ssh_keys.map(&:id).join(',')

        # Create
        say "creating a new droplets..."
        result = @api.droplets.create(:name => @name,
          :size_id    => @attributes[:size_id],
          :image_id   => @attributes[:image_id],
          :region_id  => @attributes[:region_id],
          :ssh_key_ids => ssh_key_ids)

        @droplet_id = result.droplet.id
        say "Created a new droplet (id: #{@droplet_id}). Booting..."

        # Boot - we need this before getting public IP
        while @api.droplets.show(@droplet_id).droplet.status.downcase != 'active'
          sleep 3
        end

        @public_ip = @api.droplets.show(@droplet_id).droplet.ip_address
        say "Done. ip address = #{@public_ip}"

        @instance = {
          :droplet_id => @droplet_id,
          :env  => @env,
          :host => @host,
          :fqdn => @fqdn,
          :name => @name,
          :ip_address => @public_ip,
          :size_id      => @attributes[:size_id],
          :size_name    => @attributes[:size_name],
          :region_id    => @attributes[:region_id],
          :region_name  => @attributes[:region_name],
          :image_id     => @attributes[:image_id],
          :image_name   => @attributes[:image_name],
        }
      end

      def choose(key, result)
        result.each{|i| say "#{i.id}: #{i.name}" }
        @attributes[:"#{key}_id"] = ask("which #{key}?: ", Integer) {|q| q.in = result.map(&:id); q.default = result.first.id }
        @attributes[:"#{key}_name"] = result.find{|i| i.id == @attributes[:"#{key}_id"] }.name
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
