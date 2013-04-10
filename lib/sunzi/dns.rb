module Sunzi
  class DNS
    attr_accessor :provider

    def initialize(config)
      @provider = config['dns']
      @subject = case @provider
      when 'linode'
        Sunzi::DNS::Linode.new(config)
      when 'route53'
        Sunzi::DNS::Route53.new(config)
      else
        abort_with "DNS #{@provider} is not valid!"
      end
    end

    def method_missing(sym, *args, &block)
      @subject.send sym, *args, &block
    end
  end
end
