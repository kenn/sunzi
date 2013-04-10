Sunzi::Dependency.load('linode')

module Sunzi
  module Cloud
    class Linode < Base
      def setup
        # Only run for the first time
        unless File.exist? 'linode/linode.yml'
          @cli.empty_directory 'linode/instances'
          @cli.template 'templates/setup/linode/linode.yml', 'linode/linode.yml'
          exit_with 'Now go ahead and edit linode.yml, then run this command again!'
        end

        @config = YAML.load(File.read('linode/linode.yml'))

        if @config['fqdn']['zone'] == 'example.com'
          abort_with 'You must have your own settings in linode.yml'
        end

        @dns = Sunzi::DNS.new(@config) if @config['dns']

        @sshkey = File.read(File.expand_path(@config['root_sshkey_path'])).chomp
        if @sshkey.match(/\n/)
          abort_with "RootSSHKey #{@sshkey.inspect} must not be multi-line! Check inside \"#{@config['root_sshkey_path']}\""
        end

        # Ask environment and hostname
        @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
        @host = ask('hostname? (only the first part of subdomain): ', String).to_s

        @fqdn = @config['fqdn'][@env].gsub(/%{host}/, @host)
        @label = @config['label'][@env].gsub(/%{host}/, @host)
        @group = @config['group'][@env]
        @api = ::Linode.new(:api_key => @config['api_key'])

        # Choose a plan
        result = @api.avail.linodeplans
        result.each{|i| say "#{i.planid}: #{i.ram}MB, $#{i.price}" }
        @planid = ask('which plan?: ', Integer) {|q| q.in = result.map(&:planid); q.default = result.first.planid }
        @plan_label = result.find{|i| i.planid == @planid }.label

        # Choose a datacenter
        result = @api.avail.datacenters
        result.each{|i| say "#{i.datacenterid}: #{i.location}" }
        @datacenterid = ask('which datacenter?: ', Integer) {|q| q.in = result.map(&:datacenterid); q.default = result.first.datacenterid }
        @datacenter_location = result.find{|i| i.datacenterid == @datacenterid }.location

        # Choose a distribution
        result = @api.avail.distributions
        if @config['distributions_filter']
          result = result.select{|i| i.label.match Regexp.new(@config['distributions_filter'], Regexp::IGNORECASE) }
        end
        result.each{|i| say "#{i.distributionid}: #{i.label}" }
        @distributionid = ask('which distribution?: ', Integer) {|q| q.in = result.map(&:distributionid); q.default = result.first.distributionid }
        @distribution_label = result.find{|i| i.distributionid == @distributionid }.label

        # Choose a kernel
        result = @api.avail.kernels
        if @config['kernels_filter']
          result = result.select{|i| i.label.match Regexp.new(@config['kernels_filter'], Regexp::IGNORECASE) }
        end
        result.each{|i| say "#{i.kernelid}: #{i.label}" }
        @kernelid = ask('which kernel?: ', Integer) {|q| q.in = result.map(&:kernelid); q.default = result.first.kernelid }
        @kernel_label = result.find{|i| i.kernelid == @kernelid }.label

        # Choose swap size
        @swap_size = ask('swap size in MB? (default: 256MB): ', Integer) { |q| q.default = 256 }

        # Go ahead?
        moveon = ask("Are you ready to go ahead and create #{@fqdn}? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Create
        say "creating a new linode..."
        result = @api.linode.create(:DatacenterID => @datacenterid, :PlanID => @planid, :PaymentTerm => @config['payment_term'])
        @linodeid = result.linodeid
        say "created a new instance: linodeid = #{@linodeid}"

        result = @api.linode.list.select{|i| i.linodeid == @linodeid }.first
        @totalhd = result.totalhd

        # Update settings
        say "Updating settings..."
        settings = { :LinodeID => @linodeid, :Label => @label, :lpm_displayGroup => @group }
        settings.update(@config['settings']) if @config['settings']
        result = @api.linode.update(settings)

        # Create a root disk
        say "Creating a root disk..."
        result = @api.linode.disk.createfromdistribution(
          :LinodeID => @linodeid,
          :DistributionID => @distributionid,
          :Label => "#{@distribution_label} Image",
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
          :KernelID => @kernelid,
          :Label => "#{@distribution_label} Profile",
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

        # Register IP to DNS
        @dns.add(@fqdn, @public_ip) if @dns

        # Save the instance info
        hash = {
          :linode_id => @linodeid,
          :env => @env,
          :host => @host,
          :fqdn => @fqdn,
          :label => @label,
          :group => @group,
          :plan_id => @planid,
          :datacenter_id => @datacenterid,
          :datacenter_location => @datacenter_location,
          :distribution_id => @distributionid,
          :distribution_label => @distribution_label,
          :kernel_id => @kernelid,
          :kernel_label => @kernel_label,
          :swap_size => @swap_size,
          :totalhd => @totalhd,
          :root_diskid => @root_diskid,
          :swap_diskid => @swap_diskid,
          :config_id => @config_id,
          :public_ip => @public_ip,
          :private_ip => @private_ip,
        }
        @cli.create_file "linode/instances/#{@label}.yml", YAML.dump(hash)

        # Boot
        say 'Done. Booting...'
        @api.linode.boot(:LinodeID => @linodeid)
      end

      def teardown(name)
        unless File.exist?("linode/instances/#{name}.yml")
          abort_with "#{name}.yml was not found in the instances directory."
        end
        @config = YAML.load(File.read('linode/linode.yml'))
        @dns = Sunzi::DNS.new(@config) if @config['dns']

        @instance = YAML.load(File.read("linode/instances/#{name}.yml"))
        @linode_id_hash = { :LinodeID => @instance[:linode_id] }
        @api = ::Linode.new(:api_key => @config['api_key'])

        # Are you sure?
        moveon = ask("Are you sure about deleting #{@instance[:fqdn]} permanently? (y/n) ", String) {|q| q.in = ['y','n']}
        exit unless moveon == 'y'

        # Shutdown first or disk deletion will fail
        say 'shutting down...'
        @api.linode.shutdown(@linode_id_hash)
        # Wait until linode.shutdown has completed
        wait_for('linode.shutdown')

        # Delete the instance
        say 'deleting linode...'
        @api.linode.delete(@linode_id_hash.merge(:skipChecks => 1))

        # Delete DNS record
        @dns.delete(@instance[:public_ip]) if @dns

        # Remove the instance config file
        @cli.remove_file "linode/instances/#{name}.yml"

        say 'Done.'
      end

      def wait_for(action)
        begin
          sleep 3
        end until @api.linode.job.list(@linode_id_hash).find{|i| i.action == action }.host_success == 1
      end
    end
  end
end
