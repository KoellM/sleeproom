# frozen_string_literal: true
require "sleeproom/record/write_status"

module SleepRoom
  module Record
    class Showroom
      SITE = "showroom"
      def initialize(room:, group: "default", queue:)
        @room = room
        @group = group
        @queue = queue
        @running = false
        @downlaoding = false
        @reconnection = false
      end

      # @param user [String]
      # @return [Boolean]
      def record(reconnection: false)
        room = @room
        Async do |task|
          api = API::RoomAPI.new(room)
          task.async do |t|
            while api.live?
              if status = SleepRoom.load_config(:status).find{|hash| hash[:room] == room}
                if !status[:pid].nil?
                  break if SleepRoom.running?(pid) == false
                else
                  break
                end
              else
                break
              end
              t.sleep 60
            end
          end.wait
          @room_id = api.room_id
          @room_name = api.room_name
          @is_live = api.live?
          @broadcast_host = api.broadcast_host
          @broadcast_key = api.broadcast_key
          if @is_live
            start_time = Time.now
            log("Live broadcast.")
            streaming_url = parse_streaming_url
            output = build_output
            pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
            downloading(streaming_url, pid, start_time)
            record
          else
            log("Status: Stop.")
            waiting_live(ws: :init)
            Async do |task|
              while true
                if @running == false && @reconnection == false
                  start_websocket
                elsif @reconnection == true
                  record
                  @reconnection = false
                  task.stop
                end
                task.sleep 10
              end
            end
          end
        rescue => e
          add_error(e)
          SleepRoom.error(e.full_message)
          log("Retry...")
          task.sleep 5
          retry
        end
      end

      def log(str)
        SleepRoom.info("[#{@room}] #{str}")
      end
      
      private
      def start_websocket()
        Async do |task|
          @running = true
          log("Broadcast Key: #{@broadcast_key}")
          waiting_live(ws: :init)
          ws = WebSocket.new(room: @room, broadcast_key: @broadcast_key, url: @broadcast_host)
          @ws = ws
          # ws status
          ws_task = task.async do |sub|
            ws.running = true
            ws.connect(task: sub) do |message|
              case message["t"].to_i
              when 101
                log("Live stop.")
                ws.running = false
                @running = false
                record
              when 104
                log("Live start.")
                start_time = Time.now
                streaming_url = parse_streaming_url
                output = build_output
                pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
                downloading(streaming_url, pid, start_time)
                ws.running = false
                @running = false
                @reconnection = true
              else
                # other
              end
            end
          rescue => e
            SleepRoom.error("WS Stop.")
            SleepRoom.error(e.full_message)
            ws.running = false
            @running = false
            add_error(e)
          end

          Async do |task|
            while @running && @downlaoding == false
              status = ws.status
              if !status[:last_ack].nil? && Time.now.to_i - status[:last_ack].to_i > 65
                ws.running = false
                @running = false
                task.stop
              end
              waiting_live(status)
              task.sleep 30
            end
          end
          task.children.each(&:wait)
        ensure
          ws.running = false
          @running = false
        end
      end

      def parse_streaming_url(task: Async::Task.current)
        api = API::StreamingAPI.new(@room_id)
        streaming_url_list = api.streaming_url
      end

      def build_output(task: Async::Task.current)
        room = @room
        group = @group
        tmp_str = configatron.default_save_name
        tmp_str = tmp_str.sub("\%TIME\%", Time.now.strftime("%Y-%m-%d-%H-%M-%S")) if tmp_str.include?("\%TIME\%")
        tmp_str = tmp_str.sub("\%ROOMNAME\%", room) if tmp_str.include?("\%ROOMNAME\%")
        File.join(group, room, "showroom", tmp_str)
      end

      def downloading(streaming_url, pid, start_time, task: Async::Task.current)
      @downlaoding = true
        @queue.add({
          room: @room,
          start_time: start_time,
          name: @room_name,
          group: @group,
          live: true,
          status: :downloading,
          streaming_url: streaming_url,
          download_pid: pid
        })
        task.async do |t|
          while true
            if !SleepRoom.running?(pid) && !API::RoomAPI.new(@room).live?
              log("Download complete.")
              @downlaoding = false
              @queue.add({
                room: @room,
                name: @room_name,
                group: @group,
                live: API::RoomAPI.new(@room).live?,
                status: :complete,
              })
              break
            end
            t.sleep 60
          end
        end.wait
      end

      def add_error(error)
        @queue.add({
          room: @room,
          name: @room_name,
          group: @group,
          status: :retry,
          error: error.message
        })
      end

      def waiting_live(status)
        @queue.add({
          room: @room,
          live: false,
          group: @group,
          name: @room_name,
          status: :waiting,
          ws: status
        })
      end
    end
  end
end
