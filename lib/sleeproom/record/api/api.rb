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
      class NotFoundError < Error; end
      USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.61 Safari/537.36"

      def self.get(url, task: Async::Task.current)
        task.async do
          http = Faraday.get(url, nil, { "User-Agent": USER_AGENT })
          if http.status == 200
            @json = JSON.parse(http.body)
          elsif http.status == 404
            raise NotFoundError
          else
            raise Error, "HTTP Error: #{http.status}"
          end
        end
      end
    end
  end
end
