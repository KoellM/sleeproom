# frozen_string_literal: true

module SleepRoom
  module Record
    module API
      class StreamingAPI
        def initialize(room_id)
          @url = STREAMING_API + "?room_id=" + room_id.to_s + "&ignore_low_stream=1"
          @json = nil
          get
        end

        def get(task: Async::Task.current)
          @json = API.get(@url).wait
        end

        def streaming_url
          if @json["streaming_url_list"].nil?
            raise Error.new("streaming url is null.")
          else
            @json["streaming_url_list"].sort_by{|hash| -hash["quality"]}.first["url"]
          end
        end
      end
    end
  end
  end
