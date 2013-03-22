Sunzi::Dependency.load('highline')

module Sunzi
  module Cloud
    class Base
      include Sunzi::Utility

      def self.choose(cli, target)
        case target
        when 'linode'
          Cloud::Linode.new(cli)
        when 'digital_ocean'
          Cloud::DigitalOcean.new(cli)
        else
          abort_with "#{target} is not valid!"
        end
      end

      def initialize(cli)
        @cli = cli
        @ui = HighLine.new
      end

      def ask(question, answer_type, &details)
        @ui.ask(@ui.color(question, :green, :bold), answer_type, &details)
      end
    end
  end
end
