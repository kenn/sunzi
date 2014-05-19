module Sunzi
  class DNS
    include Sunzi::Utility

    def initialize(config, cloud)
      dns = config['dns']
      @subject = case dns
      when 'linode'
        Sunzi::DNS::Linode.new(config, cloud)
      when 'route53'
        Sunzi::DNS::Route53.new(config, cloud)
      else
        abort_with "DNS #{dns} is not valid!"
      end
    end

    def method_missing(sym, *args, &block)
      @subject.send sym, *args, &block
    end

    def respond_to?(method)
      @subject.respond_to?(sym) || super
    end
  end
end
