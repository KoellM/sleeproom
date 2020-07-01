# frozen_string_literal: true

module SleepRoom
  module Record
    module API
      class StreamingAPI
        STREAMING_API = "https://www.showroom-live.com/api/live/streaming_url"
        def initialize(room_id)
          @url = STREAMING_API + "?room_id=" + room_id.to_s + "&ignore_low_stream=1"
          @json = nil
          get
        end

        def get
          @json = API.get(@url).wait
        end

        def streaming_url
          if @json["streaming_url_list"].nil?
            raise Error, "streaming url is null."
          else
            @json["streaming_url_list"].min_by { |hash| -hash["quality"] }["url"]
          end
        end
      end
    end
  end
  end
