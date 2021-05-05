# frozen_string_literal: true

require "sleeproom/async/websocket"
require "async/http/endpoint"
require "async/websocket/client"
require "json"

module SleepRoom
  module Record
    class WebSocket
      def initialize(room:, broadcast_key:, url:, open_handler:, message_handler:, close_handler:, error_handler:, ping_handler:)
        @room = room
        @url = "wss://" + url
        @broadcast_key = broadcast_key
        @running = false
        @endpoint = Async::HTTP::Endpoint.parse(@url)
        @open_handler = open_handler
        @message_handler = message_handler
        @close_handler = close_handler
        @error_handler = error_handler
        @ping_handler = ping_handler
      end

      def connect(task: Async::Task.current)
        websocket = Async::WebSocket::Client.connect(@endpoint, handler: WebSocketConnection) do |connection|
          @connection = connection
          @running = true
          send("SUB\t#{@broadcast_key}")

          log("Connect to websocket server.")
          @open_handler.call

          ping = task.async do |task|
            loop do
              task.sleep 60
              send("PING\tshowroom")
            end
          end

          while message = connection.read
            debug("ACK: #{message}")
            @ping_handler.call if message == "ACK\tshowroom"

            next unless message.start_with?("MSG")

            begin
              @message_handler.call(JSON.parse(message.split("\t")[2]))
            rescue JSON::ParserError => e
              @error_handler.call(e)
              log(e.message)
            end
          end
        rescue => e
          error "error"
          @error_handler.call(e)
          log(e.full_message)
        ensure
          ping&.stop
          @close_handler.call(nil)
          @running = false
          log("WebSocket closed.")
        end
      end

      def send(data)
        debug("SEND: #{data}")
        @connection.write(data)
        @connection.flush
      end

      def running?
        @running
      end

      def stop
        @connection.close
      end

      def log(str)
        SleepRoom.info("[#{@room}] #{str}")
      end

      def error(str)
        SleepRoom.error("[#{@room}] #{str}")
      end

      def debug(str)
        SleepRoom.debug("[#{@room}] #{str}")
      end
    end
  end
end