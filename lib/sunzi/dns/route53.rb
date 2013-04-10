Sunzi::Dependency.load('route53')

module Sunzi
  class DNS
    class Route53 < Base
      def initialize(config, cloud)
        @api = ::Route53::Connection.new(config['route53']['key'], config['route53']['secret'])
        zone = config['fqdn']['zone']
        @route53_zone = @api.get_zones.find{|i| i.name.sub(/\.$/,'') == zone }
        abort_with "zone for #{zone} was not found on Route 53!" unless @route53_zone
      end

      def add(fqdn, ip)
        say 'adding the public IP to Route 53...'
        ::Route53::DNSRecord.new(fqdn, "A", "300", [ip], @route53_zone).create
      end

      def delete(ip)
        say 'deleting the public IP from Route 53...'
        record = @route53_zone.get_records.find{|i| i.values.first == ip }
        record.delete if record
      end
    end
  end
end
