Sunzi::Dependency.load('linode')

module Sunzi
  class DNS
    class Linode < Base
      def initialize(config, cloud)
        @api = ::Linode.new(:api_key => (cloud == 'linode') ? config['api_key'] : config['linode']['api_key'])
        zone = config['fqdn']['zone']
        @domain = @api.domain.list.find{|i| i.domain == zone }
        abort_with "zone for #{zone} was not found on Linode DNS!" unless @domain
      end

      def add(fqdn, ip)
        say 'adding the public IP to Linode DNS Manager...'
        @api.domain.resource.create(:DomainID => @domain.domainid, :Type => 'A', :Name => fqdn, :Target => ip)
      end

      def delete(ip)
        say 'deleting the public IP from Linode DNS Manager...'
        resource = @api.domain.resource.list(:DomainID => @domain.domainid).find{|i| i.target == ip }
        abort_with "ip address #{ip} was not found on Linode DNS!" unless resource
        @api.domain.resource.delete(:DomainID => @domain.domainid, :ResourceID => resource.resourceid)
      end
    end
  end
end
