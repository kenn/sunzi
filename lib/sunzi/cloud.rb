module Sunzi
  class Cloud
    def initialize(cli, provider)
      @subject = case provider
      when 'linode'
        Sunzi::Cloud::Linode.new(cli, provider)
      when 'digital_ocean'
        Sunzi::Cloud::DigitalOcean.new(cli, provider)
      else
        abort_with "#{provider} is not valid!"
      end
    end

    def method_missing(sym, *args, &block)
      @subject.send sym, *args, &block
    end
  end
end
