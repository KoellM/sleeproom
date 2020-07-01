# frozen_string_literal: true

require "backports/2.5" if RUBY_VERSION < "2.5.0"
require "ruby-next"
require "optparse"
require "yaml"
require "sleeproom/record"

module SleepRoom
  class CLI
    # @param argv [Array]
    def initialize(argv)
      SleepRoom.reload_config
      @options = {}
      build
      if argv.empty? == false
        @parser.parse!(argv)
        action = argv.shift
        case action
        when "status"
          SleepRoom::Record::Tasks.status
        when "start"
          SleepRoom::Record::Tasks.start(**@options)
        when "lists"
          SleepRoom::Record::Tasks.lists
        end
        exit(0)
      else
        puts @parser
        exit(0)
      end
    end

    # @return [void]
    def build
      @parser = OptionParser.new do |opt|
        opt.version = "SleepRoom / #{SleepRoom::VERSION}"
        opt.banner = opt.version.to_s
        opt.banner += "\nUsage: sleeproom [Options]\n\n"

        opt.banner += "Action:\n"
        opt.banner += "status".rjust(10)
        opt.banner += "显示任务状态".rjust(33)
        opt.banner += "\n"
        opt.banner += "list".rjust(8)
        opt.banner += "显示录制列表".rjust(35)
        opt.banner += "\n"
        opt.banner += "exit".rjust(8)
        opt.banner += "关闭任务队列".rjust(35)
        opt.banner += "\n\nCommands:\n"

        opt.on("-a ROOM, NAME", "--add ROOM, GROUP", Array, "添加到监视列表") do |room|
          SleepRoom::Record::Tasks.add(room[0].to_s, room[1].to_s)
        end

        opt.on("-r", "--remove [ROOM]", "从监视列表移除") do |room|
          SleepRoom::Record::Tasks.remove(room)
        end

        opt.on("-d", "--download [ROOM]", "录制指定房间") do |room|
          raise Error, "房间名不能为空" if room.nil?

          room = room.match(%r{https://www.showroom-live.com/(.*)})[1] if room.match?("https://www.showroom-live.com/")
          write_status = SleepRoom::Record::WriteStatus.new
          Async do
            record = SleepRoom::Record::Showroom.new(room: room, group: "download", queue: write_status)
            record.record
          end
        end

        opt.on("-v", "--verbose", "Print log") do
          @options[:verbose] = true
        end

        opt.on_tail("--version", "Print version") do
          STDOUT.puts(opt.version)
        end

        opt.on_tail("-h", "--help", "Print help") do
          STDOUT.puts(opt)
        end
      end
    end
  end
end
