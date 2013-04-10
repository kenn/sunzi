Sunzi::Dependency.load('linode')

module Sunzi
  class Cloud
    class Linode < Base
      def do_setup
        @sshkey = File.read(File.expand_path(@config['root_sshkey_path'])).chomp
        if @sshkey.match(/\n/)
          abort_with "RootSSHKey #{@sshkey.inspect} must not be multi-line! Check inside \"#{@config['root_sshkey_path']}\""
        end

        choose(:plan, @api.avail.linodeplans)
        choose(:datacenter, @api.avail.datacenters, :label_method => :location)
        choose(:distribution, @api.avail.distributions, :filter => 'distributions_filter')
        choose(:kernel, @api.avail.kernels, :filter => 'kernels_filter')

        # Choose swap size
        @swap_size = ask('swap size in MB? (default: 256MB): ', Integer) { |q| q.default = 256 }

        # Go ahead?
        proceed?

        # Create
        say "creating a new linode..."
        result = @api.linode.create(:DatacenterID => @attributes[:datacenterid], :PlanID => @attributes[:planid], :PaymentTerm => @config['payment_term'])
        @linodeid = result.linodeid
        say "created a new instance: linodeid = #{@linodeid}"

        result = @api.linode.list.select{|i| i.linodeid == @linodeid }.first
        @totalhd = result.totalhd

        # Update settings
        say "Updating settings..."
        @group = @config['group'][@env]
        settings = { :LinodeID => @linodeid, :Label => @name, :lpm_displayGroup => @group }
        settings.update(@config['settings']) if @config['settings']
        @api.linode.update(settings)

        # Create a root disk
        say "Creating a root disk..."
        result = @api.linode.disk.createfromdistribution(
          :LinodeID => @linodeid,
          :DistributionID => @attributes[:distributionid],
          :Label => "#{@attributes[:distribution_label]} Image",
          :Size => @totalhd - @swap_size,
          :rootPass => @config['root_pass'],
          :rootSSHKey => @sshkey
        )
        @root_diskid = result.diskid

        # Create a swap disk
        say "Creating a swap disk..."
        result = @api.linode.disk.create(
          :LinodeID => @linodeid,
          :Label => "#{@swap_size}MB Swap Image",
          :Type => 'swap',
          :Size => @swap_size
        )
        @swap_diskid = result.diskid

        # Create a config profiile
        say "Creating a config profile..."
        result = @api.linode.config.create(
          :LinodeID => @linodeid,
          :KernelID => @attributes[:kernelid],
          :Label => "#{@attributes[:distribution_label]} Profile",
          :DiskList => [ @root_diskid, @swap_diskid ].join(',')
        )
        @config_id = result.configid

        # Add a private IP
        say "Adding a private IP..."
        result = @api.linode.ip.list(:LinodeID => @linodeid)
        @public_ip = result.first.ipaddress
        result = @api.linode.ip.addprivate(:LinodeID => @linodeid)
        result = @api.linode.ip.list(:LinodeID => @linodeid).find{|i| i.ispublic == 0 }
        @private_ip = result.ipaddress

        @instance = {
          :linode_id => @linodeid,
          :env => @env,
          :host => @host,
          :fqdn => @fqdn,
          :label => @name,
          :group => @group,
          :plan_id =>             @attributes[:planid],
          :datacenter_id =>       @attributes[:datacenterid],
          :datacenter_location => @attributes[:datacenter_location],
          :distribution_id =>     @attributes[:distributionid],
          :distribution_label =>  @attributes[:distribution_label],
          :kernel_id =>           @attributes[:kernelid],
          :kernel_label =>        @attributes[:kernel_label],
          :swap_size => @swap_size,
          :totalhd => @totalhd,
          :root_diskid => @root_diskid,
          :swap_diskid => @swap_diskid,
          :config_id => @config_id,
          :public_ip => @public_ip,
          :private_ip => @private_ip,
        }

        # Boot
        say 'Done. Booting...'
        @api.linode.boot(:LinodeID => @linodeid)
      end

      def choose(key, result, options = {})
        label_method = options[:label_method] || :label
        id    = :"#{key}id"
        label = :"#{key}_#{label_method}"

        # Filters
        if options[:filter] and @config[options[:filter]]
          result = result.select{|i| i.label.match Regexp.new(@config[options[:filter]], Regexp::IGNORECASE) }
        end

        result.each{|i| say "#{i.send(id)}: #{i.send(label_method)}" }
        @attributes[id] = ask("which #{key}?: ", Integer) {|q| q.in = result.map(&id); q.default = result.first.send(id) }
        @attributes[label] = result.find{|i| i.send(id) == @attributes[id] }.send(label_method)
        p @attributes
      end

      def do_teardown
        @linode_id_hash = { :LinodeID => @instance[:linode_id] }

        # Shutdown first or disk deletion will fail
        say 'shutting down...'
        @api.linode.shutdown(@linode_id_hash)
        # Wait until linode.shutdown has completed
        wait_for('linode.shutdown')

        # Delete the instance
        say 'deleting linode...'
        @api.linode.delete(@linode_id_hash.merge(:skipChecks => 1))
      end

      def assign_api
        @api = ::Linode.new(:api_key => @config['api_key'])
      end

      def ip_key
        :public_ip
      end

      def wait_for(action)
        begin
          sleep 3
        end until @api.linode.job.list(@linode_id_hash).find{|i| i.action == action }.host_success == 1
      end
    end
  end
end
