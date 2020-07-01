# frozen_string_literal: true

require "sleeproom/async/websocket"
require "async/http/endpoint"
require "async/websocket/client"
require "json"

module SleepRoom
  module Record
    class WebSocket
      attr_accessor :last_ack
      def initialize(room:, broadcast_key:, url:)
        @room = room
        @url = "wss://" + url
        @broadcast_key = broadcast_key
        @running = false
        @last_ack = nil
      end

      def connect(task: Async::Task.current)
        url = @url
        endpoint = Async::HTTP::Endpoint.parse(url)
        Async::WebSocket::Client.connect(endpoint, handler: WebSocketConnection) do |connection|
          begin
            @connection = connection
            @running = true
            connection.write("SUB\t#{@broadcast_key}")
            connection.flush
            log("Connect to websocket server.")
            yield :status, { event: :connect, time: Time.now }

            ping_task = task.async do |sub|
              while @running
                sub.sleep 60
                connection.write("PING\tshowroom")
                connection.flush
              end
            end

            status_task = task.async do |sub|
              loop do
                sub.sleep 1
                connection.close if @running == false
              end
            end

            reconnect_task = task.async do |t|
              loop do
                t.sleep 10
                if !@last_ack.nil? && Time.now.to_i - @last_ack.to_i > 65
                  begin
                    yield :status, { event: :close, time: Time.now }
                    connection.close
                  rescue
                  end
                end
              end
            end
            while message = connection.read
              if message == "ACK\tshowroom"
                @last_ack = Time.now
                yield :status, { event: :ack, time: Time.now } if message == "ACK\tshowroom"
              end
              next unless message.start_with?("MSG")

              begin
                yield :websocket, JSON.parse(message.split("\t")[2])
              rescue => e
                SleepRoom.error(e.message)
              end
            end
          rescue => e
            yield :status, { event: :error, error: e }
            SleepRoom.error(e.message)
          ensure
            ping_task&.stop
            status_task&.stop
            connection.close
            reconnect_task&.stop
            log("WebSocket closed.")
          end
        end
      end

      def running?
        @running
      end

      attr_writer :running

      def stop
        @running = false
        @connection.close
      end

      def log(str)
        SleepRoom.info("[#{@room}] #{str}")
      end
  end
  end
end
