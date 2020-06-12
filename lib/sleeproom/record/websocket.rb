require "sleeproom/async/websocket"
require "async/http/endpoint"
require "async/websocket/client"
require "json"

module SleepRoom
    module Record
        class WebSocket
          attr_accessor :queue
          def initialize(room:, broadcast_key:, url:)
            @room = room
            @url = "wss://" + url
            @broadcast_key = broadcast_key
            @running = false
            @queue = Async::Queue.new
          end

          def connect(task: Async::Task.current)
            url = @url
            endpoint = Async::HTTP::Endpoint.parse(url)
              Async::WebSocket::Client.connect(endpoint, handler: WebSocketConnection) do |connection|
                @connection = connection
                @running = true
                connection.write("SUB\t#{@broadcast_key}")
                connection.flush
                log("Connect to websocket server.")
                @queue.enqueue({event: :connect, time: Time.now})
                
                ping_task = task.async do |sub|
                  while @running
                    sub.sleep 60
                    @queue.enqueue({event: :ping, time: Time.now})
                    connection.write("PING\tshowroom")
                    connection.flush
                  end
                end

                status_task = task.async do |sub|
                  while true
                    sub.sleep 1
                    if @running == false
                      connection.close
                    end
                  end
                end

                while message = connection.read
                  if message == "ACK\tshowroom"
                    @queue.enqueue({event: :ack, time: Time.now}) if message == "ACK\tshowroom"
                  end
                  if message.start_with?("MSG")
                    begin
                      yield JSON.parse(message.split("\t")[2])
                    rescue => e
                      SleepRoom.error(e.message)
                    end
                  end
                end
              rescue => e
                SleepRoom.error(e.message)
              ensure
                ping_task&.stop
                connection.close
                log("WebSocket closed.")
              end
          end
          
          def running?
            @running
          end

          def running=(bool)
            @running = bool
          end

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