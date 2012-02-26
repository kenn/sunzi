Sunzi::Dependency.load('linode')

# Workaround the bug: https://github.com/rick/linode/issues/12
YAML::ENGINE.yamler = 'syck'

module Sunzi
  module Cloud
    class Linode < Base
      no_tasks do

        def setup
          # Only run for the first time
          unless File.exist? 'linode/linode.yml'
            empty_directory 'linode'
            empty_directory 'linode/instances'
            template 'templates/setup/linode/linode.yml', 'linode/linode.yml'
            say shell.set_color('Now go ahead and edit linode.yml, then run this command again!', :green, true)
            abort
          end

          @config = YAML.load(File.read('linode/linode.yml'))

          if @config['fqdn']['zone'] == 'example.com'
            say shell.set_color('You must have your own settings in linode.yml', :red, true)
            abort
          end

          # When route53 is specified for DNS, check if it's properly configured and if not, fail earlier.
          setup_route53 if @config['dns'] == 'route53'

          @ui = HighLine.new

          @sshkey = File.read(File.expand_path(@config['root_sshkey_path'])).chomp
          if @sshkey.match(/\n/)
            say shell.set_color("RootSSHKey #{@sshkey.inspect} must not be multi-line! Check inside \"#{@config['root_sshkey_path']}\"", :red, true)
            abort
          end

          # Ask environment and hostname
          @env = ask("environment? (#{@config['environments'].join(' / ')}): ", String) {|q| q.in = @config['environments'] }.to_s
          @host = ask('hostname? (only the last part of subdomain): ', String).to_s

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
          moveon = ask("Are you sure to go ahead and create #{@fqdn}? (y/n) ", String) {|q| q.in = ['y','n']}
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
          result = @api.linode.update(
            :LinodeID => @linodeid,
            :Label => @label,
            :lpm_displayGroup => @group,
            # :Alert_cpu_threshold => 90,
            # :Alert_diskio_threshold => 1000,
            # :Alert_bwin_threshold => 5,
            # :Alert_bwout_threshold => 5,
            # :Alert_bwquota_threshold => 80,
          )

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
          case @config['dns']
          when 'linode'
            # Set the public IP to Linode DNS Manager
            say "Setting the public IP to Linode DNS Manager..."
            @domainid = @api.domain.list.find{|i| i.domain == @config['fqdn']['zone'] }.domainid
            @api.domain.resource.create(:DomainID => @domainid, :Type => 'A', :Name => @fqdn, :Target => @public_ip)
          when 'route53'
            # Set the public IP to AWS Route 53
            say "Setting the public IP to AWS Route 53..."
            Route53::DNSRecord.new(@fqdn, "A", "300", [@public_ip], @route53_zone).create
          end

          # Boot
          say shell.set_color("Done. Booting...", :green, true)
          @api.linode.boot(:LinodeID => @linodeid)

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

          File.open("linode/instances/#{@label}.yml",'w') do |file|
            file.write YAML.dump(hash)
          end
        end

        def teardown(name)
          unless File.exist?("linode/instances/#{name}.yml")
            say shell.set_color("#{name}.yml was not found in the instances directory.", :red, true)
            abort
          end
          @config = YAML.load(File.read('linode/linode.yml'))
          setup_route53 if @config['dns'] == 'route53'

          @instance = YAML.load(File.read("linode/instances/#{name}.yml"))
          @api = ::Linode.new(:api_key => @config['api_key'])

          # Shutdown first or disk deletion will fail
          say shell.set_color("shutting down...", :green, true)
          @api.linode.shutdown(:LinodeID => @instance[:linode_id])
          sleep 10

          # Delete the disks. It is required - http://www.linode.com/api/linode/linode%2Edelete
          say shell.set_color("deleting root disk...", :green, true)
          @api.linode.disk.delete(:LinodeID => @instance[:linode_id], :DiskID => @instance[:root_diskid]) rescue nil
          say shell.set_color("deleting swap disk...", :green, true)
          @api.linode.disk.delete(:LinodeID => @instance[:linode_id], :DiskID => @instance[:swap_diskid]) rescue nil
          sleep 5

          # Delete the instance
          say shell.set_color("deleting linode...", :green, true)
          @api.linode.delete(:LinodeID => @instance[:linode_id])

          # Delete DNS record
          case @config['dns']
          when 'linode'
            # Set the public IP to Linode DNS Manager
            say "deleting the public IP to Linode DNS Manager..."
            @domainid = @api.domain.list.find{|i| i.domain == @config['fqdn']['zone'] }.domainid
            @resource = @api.domain.resource.list(:DomainID => @domainid).find{|i| i.target == @instance[:public_ip] }
            @api.domain.resource.delete(:DomainID => @domainid, :ResourceID => @resource.resourceid)
          when 'route53'
            # Set the public IP to AWS Route 53
            say "deleting the public IP to AWS Route 53..."
            @record = @route53_zone.get_records.find{|i| i.values.first == @instance[:public_ip] }
            @record.delete
          end

          # Remove the instance config file
          remove_file "linode/instances/#{name}.yml"

          say shell.set_color("Done.", :green, true)
        end

        def setup_route53
          Sunzi::Dependency.load('route53')
          route53 = Route53::Connection.new(@config['route53']['key'], @config['route53']['secret'])
          @route53_zone = route53.get_zones.find{|i| i.name.sub(/\.$/,'') == @config['fqdn']['zone'] }
        end
      end
    end
  end
end
