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
            if old_status.find { |h| h[:room] == room }
              new_status = old_status.delete_if { |h| h[:room] == room }
              new_status.push(status)
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
    end
  end
end
