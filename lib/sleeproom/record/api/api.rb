# frozen_string_literal: true

require "async/http/faraday"
require "async/http/faraday/default"
require_relative "room"
require_relative "room_api"
require_relative "streaming_api"

module SleepRoom
  module Record
    module API
      class Error < StandardError; end
      ROOM_URL = "https://www.showroom-live.com"
      ROOM_API = "https://www.showroom-live.com/api/room/status"
      STREAMING_API = "https://www.showroom-live.com/api/live/streaming_url"

      USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.61 Safari/537.36"

      def self.get(url)
        Async do
          http = Faraday.get(url, nil, {"User-Agent": USER_AGENT})
          if http.status == 200
            @json = JSON.parse(http.body)
          else
            raise Error, "HTTP Error: #{http.status}"
          end
        end
      end
    end
  end
end
