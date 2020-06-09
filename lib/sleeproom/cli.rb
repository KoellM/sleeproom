# frozen_string_literal: true

require "optparse"
require "yaml"
require "sleeproom/record"

module SleepRoom
  class CLI
    # @param argv [Array]
    def initialize(argv)
      @options = {}
      build
      unless argv.empty?
        @parser.parse!(argv)
        action = argv.shift
        if action == "status"
          SleepRoom::Record::Tasks.status
        elsif action == "start"
          SleepRoom::Record::Tasks.start
        elsif action == "download"
          raise "未实现"
        elsif action == "exit"
          SleepRoom::Record::Tasks.stop
        end
        exit(0)
      else
        puts @parser
        exit(0)
      end
    end

    # @return [void]
    def run
      SleepRoom::Record::Tasks.start
    end

    # @return [void]
    def build
      @parser = OptionParser.new do |opt|
        opt.version = "SleepRoom / #{SleepRoom::VERSION}"
        opt.banner = "#{opt.version}"
        opt.banner += "\nUsage: sleeproom [Options]\n\n"

        opt.banner += "Action:\n"
        opt.banner += "status".rjust(10)
        opt.banner += "显示任务状态".rjust(33)
        opt.banner += "\n"
        opt.banner += "exit".rjust(8)
        opt.banner += "关闭任务队列".rjust(35)
        opt.banner += "\n\nCommands:\n"

        opt.on("-a ROOM, NAME", "--add ROOM, GROUP", Array, "添加到监视列表") do |room|
          SleepRoom::Record::Tasks.add(room[0].to_s, room[1].to_s)
        end

        opt.on("-r", "--remove [URL]", "从监视列表移除") do |room|
          SleepRoom::Record::Tasks.remove(room)
        end

        opt.on("-v", "--verbose", "Print log") do
          @options[:verbose] = true
        end

        opt.on("-d", "daemon", "Daemonize the script into the background") do
          @options[:daemon] = true
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
