Sunzi::Dependency.load('highline')

module Sunzi
  module Cloud
    class Base < Thor
      include Thor::Actions

      class << self
        def source_root
          File.expand_path('../../../',__FILE__)
        end

        def choose(target)
          case target
          when 'linode'
            Cloud::Linode.new
          when 'ec2'
            Cloud::EC2.new
          else
            say shell.set_color("#{target} is not valid!", :red, true)
            abort
          end
        end
      end

      def initialize(*args)
        @ui = HighLine.new
        super
      end

      no_tasks do
        def ask(question, answer_type, &details)
          @ui.ask(@ui.color(question, :green, :bold), answer_type, &details)
        end
      end
    end
  end
end
