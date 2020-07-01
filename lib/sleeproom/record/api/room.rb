# frozen_string_literal: true

module SleepRoom
  module Record
    module API
      class Room
        ROOM_URL = "https://www.showroom-live.com"
        def initialize(room_name)
          @url = ROOM_URL + "/" + room_name
        end

        def get
          @json = API.get(@url).wait
        end
      end
    end
  end
end
