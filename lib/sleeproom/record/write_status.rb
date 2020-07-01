# frozen_string_literal: true

require "async/queue"
module SleepRoom
  module Record
    class WriteStatus
      attr_accessor :queue
      def initialize
        @queue = Async::Queue.new
      end

      def run
        Async do
          while status = @queue.dequeue
            status[:update] = Time.now
            old_status = SleepRoom.load_config(:status)
            room = status[:room]
            if tmp_status = old_status.find { |h| h[:room] == room }
              new_status = old_status.delete_if { |h| h[:room] == room }
              unless tmp_status[:status] == :downloading && status[:status] == :waiting
                new_status.push(tmp_status.merge!(status))
              end
            else
              new_status = old_status.push(status)
            end
            SleepRoom.write_config_file(:status, new_status)
          end
        end
      end

      def add(status)
        Async do
          @queue.enqueue(status)
        end
      end

      def downloading(room:, url:, pid:, start_time:)
        add(
          {
            room: room,
            live: true,
            status: :downloading,
            streaming_url: url,
            pid: pid,
            start_time: start_time
          }
        )
      end

      def waiting(room:, group:, room_name:)
        add(
          {
            room: room,
            live: false,
            group: group,
            name: room_name,
            status: :waiting,
          }
        )
      end
    end
  end
end
