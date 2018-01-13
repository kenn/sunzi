module Sunzi
  module Utility
    def abort_with(text)
      abort text.color(:red).bright
    end

    def exit_with(text)
      exit text.color(:green).bright
    end
  end
end
