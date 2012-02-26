module Sunzi
  module Cloud
    class EC2 < Base
      no_tasks do
        def setup
          say shell.set_color('EC2 is not implemented yet!', :red, true)
        end

        def teardown(target)
          say shell.set_color('EC2 is not implemented yet!', :red, true)
        end
      end
    end
  end
end
