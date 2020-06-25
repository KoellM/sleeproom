# frozen_string_literal: true
require "sleeproom/record/write_status"

module SleepRoom
  module Record
    class Showroom
      def initialize(room:, group: "default", queue:)
        @room = room
        @group = group
        @queue = queue
        @running = false
        @downloading = false
        @reconnection = false
        @pid = nil
      end

      # @param user [String]
      # @return [Boolean]
      def record(reconnection: false, main_task: Async::Task.current)
        room = @room
        main_task.async do |task|
          set_room_info
          while @is_live
            if @pid
              next if SleepRoom.running?(@pid)
            end
            break
          task.sleep 1
          end
          if @is_live
            start_time = Time.now
            log("Live broadcast.")
            streaming_url = parse_streaming_url
            output = build_output
            call_time = Time.now
            pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
            downloading(streaming_url, pid, start_time)
            path = SleepRoom.find_tmp_directory(output, call_time)
            SleepRoom.move_ts_to_archive(path)
            record
          else
            log("Status: Stop.")
            waiting_live(ws: :init)
            while true
              if @running == false && @reconnection == false
                start_websocket
              elsif @reconnection
                set_room_info
                start_websocket
                @reconnection = false
              end
              task.sleep 1
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
      def start_websocket(main_task: Async::Task.current)
        main_task.async do |task|
          @running = true
          log("Broadcast Key: #{@broadcast_key}")
          waiting_live(ws: :init)
          ws = WebSocket.new(room: @room, broadcast_key: @broadcast_key, url: @broadcast_host)
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
                call_time = Time.now
                pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
                path = SleepRoom.find_tmp_directory(output, call_time)
                SleepRoom.move_ts_to_archive(path)
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

          main_task.async do |task|
            last_ack = nil
            last_ping = nil
            while @running && @downloading == false
              queue = ws.queue.items
              if !queue.empty?
                queue.each do |event|
                  case event[:event]
                  when :ack
                    last_ack = event[:time]
                  when :ping
                    last_ping = event[:ping]
                  end
                end
              end
              if !last_ack.nil? && Time.now.to_i - last_ack.to_i > 65
                ws.running = false
                @running = false
                task.stop
              end
              waiting_live({last_ack: last_ack})
              task.sleep 1
            end
          end
          task.children.each(&:wait)
        ensure
          ws.running = false
          @running = false
        end
      end
      
      def set_room_info(task: Async::Task.current)
        api = API::RoomAPI.new(@room)
        @room_id = api.room_id
        @room_name = api.room_name
        @is_live = api.live?
        @broadcast_host = api.broadcast_host
        @broadcast_key = api.broadcast_key
      rescue API::NotFoundError
        SleepRoom.error("[#{@room}] The room does not exist.")
        log("Task stopped.")
        Async::Task.current.stop
      rescue => e
        SleepRoom.error(e.message)
        log("[setRoomInfo] Retry...")
        task.sleep 5
        retry
      end

      def parse_streaming_url(task: Async::Task.current)
        api = API::StreamingAPI.new(@room_id)
        streaming_url_list = api.streaming_url
      rescue => e
        SleepRoom.error(e.full_message)
        log("[parseStreamingUrl] Retry...")
        retry
      end

      def build_output(task: Async::Task.current)
        room = @room
        group = @group
        tmp_str = configatron.default_save_name
        tmp_str = tmp_str.sub("\%TIME\%", Time.now.strftime("%Y-%m-%d-%H-%M-%S")) if tmp_str.include?("\%TIME\%")
        tmp_str = tmp_str.sub("\%ROOMNAME\%", room) if tmp_str.include?("\%ROOMNAME\%")
        File.join(group, room, tmp_str)
      end

      def downloading(streaming_url, pid, start_time, task: Async::Task.current)
        @downloading = true
        @pid = pid
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
        loop do
          if !SleepRoom.running?(pid) && !@is_live
            @pid = nil
            log("Download complete.")
            @downloading = false
            @queue.add({
              room: @room,
              name: @room_name,
              group: @group,
              live: API::RoomAPI.new(@room).live?,
              status: :complete,
            })
            break
          elsif @is_live && !SleepRoom.running?(pid)
            @is_live = API::RoomAPI.new(@room).live?
            next if @is_live == false
            log("Minyami crash.")
            streaming_url = parse_streaming_url
            output = build_output
            pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
            @pid = pid
          elsif !@is_live && SleepRoom.running?(pid)
            log("Live stop.")
          end
          task.sleep 1
        rescue Faraday::ConnectionFailed
          log("Network error.")
          retry
        end
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
