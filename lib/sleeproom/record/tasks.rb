# frozen_string_literal: true
require "terminal-table"

module SleepRoom
  module Record
    class Tasks
      # @return [void]
      def self.start
        Async do |_task|
          count = 0
          write_status = WriteStatus.new
          SleepRoom.reload_config
          if SleepRoom.running?
            SleepRoom.error("PID #{SleepRoom.load_pid} Process is already running.")
            exit
          else
            SleepRoom.write_config_file(:status, [])
          end
          SleepRoom.create_pid(Process.pid)
          lists = SleepRoom.load_config(:record)
          lists.each do |group, list|
            SleepRoom.info("Empty list.") if list.empty?
            list.each do |room|
              record = SleepRoom::Record::Showroom.new(room: room["room"], group: group, queue: write_status)
              record.record
              count += 1
            end
          rescue 
            SleepRoom.error("Cannot parse Recording list.")
          end
          write_status.run
          SleepRoom.info("共启动 #{count} 个任务.")
          wait
        rescue => e
          puts e.full_message
        end
      rescue Exception
        SleepRoom.create_pid(nil) unless SleepRoom.running?
        puts "Exit..."
      end

      # @return [void]
      def self.stop
        SleepRoom.reload_config
        raise "未实现"
      end

      # @return [void]
      def self.status
        Async do
          SleepRoom.reload_config
          status = SleepRoom.load_status
          pid = SleepRoom.load_config(:pid)
          if !SleepRoom.running?(pid) || status.empty? || pid.nil?
            lists = SleepRoom.load_config(:record)
            SleepRoom.info("No tasks running.")
            lists.each do |group, list|
              next if list.empty?
              rows = []
              title = group
              headings = list[0].keys
              list.each do |hash|
                rows.push(hash.values)
              end
              puts Terminal::Table.new(title: "[Recording list] Group: #{title}",:rows => rows, headings: headings)
            end
          else
            rows = []
            headings = status[0].keys
            status.each do |hash|
              rows.push(
                hash.values.map do |s|
                  if s.is_a?(Hash)
                    "#{(s[:last_ack].is_a?(Time) ? "[ACK]" + s[:last_ack].strftime("%H:%M:%S").to_s : "nil")}"
                  elsif s.is_a?(Time)
                    s.strftime("%H:%M:%S")
                  else
                    s.to_s
                  end
                end
              )
            end
            puts Terminal::Table.new(title: "Status [PID #{pid}] (#{status.count})",:rows => rows, headings: headings)
          end
        end
      end

      def self.add(room, group)
        Async do
          group = "default" if group.empty?
          old_record = SleepRoom.load_config(:record)
          name = API::RoomAPI.new(room).room_name
          input_record = {"room" => room, "name" => name}
          if !old_record[group].nil? && new_record = old_record[group].find{|h| h = input_record if h["room"] == room}
            SleepRoom.error("Room #{room} already exists.")
          else
            old_record[group] = [] if old_record[group].nil?
            old_record[group].push(input_record)
            new_record = old_record
            SleepRoom.write_config_file(:record, new_record)
            SleepRoom.info("Added success.")
          end
        end
      end

      def self.remove(room)
        old_record = SleepRoom.load_config(:record)
        new_record = old_record.each {|k, v| v.delete_if { |h| h["room"] == room }}
        SleepRoom.write_config_file(:record, new_record)
        SleepRoom.info("Remove success.")
      end

      private
      def self.wait
        Async do |task|
          while true
            task.sleep 1
          end
        end
      end
    end
  end
end
