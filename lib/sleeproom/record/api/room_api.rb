# frozen_string_literal: true

module SleepRoom
  module Record
    module API
      class RoomAPI
        def initialize(room_url_key)
          @url = ROOM_API + "?room_url_key=" + room_url_key
          @json = nil
          get
        end

        def get(task: Async::Task.current)
          @json = API.get(@url).wait
        end

        def live?
          @json["is_live"]
        end

        def broadcast_key
          @json["broadcast_key"].to_s
        end

        def broadcast_host
          @json["broadcast_host"].to_s
        end

        def room_id
          @json["room_id"]
        end

        def room_name
          @json["room_name"]
        end
      end
    end
  end
  end
