# frozen_string_literal: true

module SleepRoom
  module Record
    module API
      class Room
        def initialize(room_name)
          @url = ROOM_URL + "/" + room_name
        end

        def get(task: Async::Task.current)
          @json = API.get(@url).wait
        end
      end
    end
  end
end
