module Sunzi
  module Logger
    class << self
      def info(text)
        puts text.bright
      end

      def success(text)
        puts text.color(:green).bright
      end

      def error(text)
        puts text.color(:red).bright
      end
    end
  end
end
