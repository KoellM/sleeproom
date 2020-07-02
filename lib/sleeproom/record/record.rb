# frozen_string_literal: true

require "sleeproom/record/write_status"

module SleepRoom
  module Record
    # showroom-live.com
    class Showroom
      # Showroom Downloader
      # @param room [String]
      # @param group [String]
      # @param queue [WriteStatus]
      def initialize(room:, group: "default", queue:)
        @room = room
        @group = group
        @status = queue
        @running = false
      end

      # Record Room
      def recore
        set_room_info
        if @is_live
          log("Status: broadcast.")
          download_process
        else
          log("Status: Stop.")
        end
        start_websocket
      rescue => e
        error(e.full_message)
        Async::Task.current.sleep 5
        retry
      end

      # Print log
      # @param str [String]
      def log(str)
        SleepRoom.info("[#{@room}] #{str}")
      end

      # Print log
      # @param str [String]
      def error(str)
        SleepRoom.error("[#{@room}] #{str}")
      end

      private

      # Websocket connect
      def start_websocket(task: Async::Task.current)
        log("Broadcast Key: #{@broadcast_key}")
        ws = WebSocket.new(room: @room, broadcast_key: @broadcast_key, url: @broadcast_host)
        @running = true
        update_status
        begin
          ws.connect do |event, message|
            if event == :websocket
              case message["t"].to_i
              when 101
                log("Live stop.")
                @is_live = false
                ws.running = false
              when 104
                log("Live start.")
                download_process
              end
            elsif event == :status
              case message[:event]
              when :ack
                update_status
              when :close
                log("WebSocket Close.")
                task.sleep 5
                record
              when :error
                error("Network Error.")
                log("Try to reconnect server.")
                task.sleep 5
                record
              end
            else
              # TODO
            end
          end
        rescue => e
          error("WebSocket stopped.")
          puts(e.full_message)
        end
      ensure
        @running = false
      end

      def set_room_info(task: Async::Task.current)
        api = API::RoomAPI.new(@room)
        @room_id = api.room_id
        @room_name = api.room_name
        @is_live = api.live?
        @broadcast_host = api.broadcast_host
        @broadcast_key = api.broadcast_key
      rescue API::NotFoundError
        error("The room does not exist.")
        log("Task stopped.")
        task.stop
      rescue => e
        error(e.message)
        log("获取房间信息失败.")
        log("等待5秒...")
        task.sleep 5
        retry
      end

      def parse_streaming_url
        api = API::StreamingAPI.new(@room_id)
        api.streaming_url
      rescue => e
        SleepRoom.error(e.full_message)
        log("获取 HLS 地址失败.")
        retry
      end

      # Downloader
      def download_process(task: Async::Task.current)
        completed = false
        log("Download start.")
        streaming_url = parse_streaming_url
        output = build_output
        # Call time
        call_time = Time.now
        pid = SleepRoom::Record.call_minyami(url: streaming_url, output: output)
        @status.downloading(room: @room, url: streaming_url, pid: pid, start_time: call_time)
        log("Waiting for download process.")
        # Status
        task.async do |t|
          loop do
            if SleepRoom.running?(pid) && @is_live
              # Downloading
            elsif SleepRoom.running?(pid) && @is_live == false
              # Live stopped, Minyami process running.
              retries = 0
              while retries < 3
                set_room_info
                break if @is_live == true

                log("Waiting for latest status...")
                task.sleep 20
                retries += 1
              end
              completed = true if retries == 3 && @is_live == false
            elsif (SleepRoom.running?(pid) == false && @is_live == false) || completed
              # Live stopped, Minyami process stopped.
              @status.add(room: @room, status: :completed, live: false)
              log("Download completed.")
              log("Find minyami temp files...")
              tmp_path = SleepRoom.find_tmp_directory(output, call_time)
              if tmp_path
                log("Temp files in #{tmp_path}.")
                save_path = File.dirname("#{configatron.save_path}/#{output}")
                dir_name = File.basename(output).sub(".ts", "")
                SleepRoom.move_ts_to_archive(tmp_path, save_path, dir_name)
                log("Save chunks to #{save_path}/#{dir_name}.")
              else
                log("Can not find temp file")
              end
              record
              @running = false
              break
            elsif SleepRoom.running?(pid) == false && @is_live == true
              # Live broadcast, Minyami process stopped.
              set_room_info
              next if @is_live == false

              log("Minyami stopped, Try to call Minyami again.")
              download_process
            end
            t.sleep 1
          end
        end
      end

      # @return [String]
      def build_output
        room = @room
        group = @group
        tmp_str = configatron.default_save_name
        tmp_str = tmp_str.sub("\%TIME\%", Time.now.strftime("%Y-%m-%d-%H-%M-%S")) if tmp_str.include?("\%TIME\%")
        tmp_str = tmp_str.sub("\%ROOMNAME\%", room) if tmp_str.include?("\%ROOMNAME\%")
        File.join(group, room, tmp_str)
      end

      def update_status
        @status.waiting(room: @room, group: @group, room_name: @room_name)
      end
    end
  end
end
