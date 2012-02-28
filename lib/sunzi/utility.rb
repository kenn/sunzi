module Sunzi
  module Utility
    def abort_with(text)
      Logger.error text
      abort
    end

    def exit_with(text)
      Logger.success text
      exit
    end

    def say(text)
      Logger.info text
    end
  end
end
