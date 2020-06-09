# frozen_string_literal: true

require "json"
require "configatron"
require "sleeproom/utils"
require "sleeproom/version"
require "sleeproom/record/record"
require "sleeproom/record/tasks"
require "sleeproom/record/websocket"
require "sleeproom/record/api/api"
require "async"
require "shellwords"
module SleepRoom
  module Record
    # Okite!!!
    # @param url [String]
    # @return [Boolean]
    def self.call_minyami(url:, is_live: true, threads: configatron.minyami.threads, output:, retries: configatron.minyami.retries)
      command = "minyami -d #{Shellwords.escape(url)}"
      command += " --retries #{retries.to_i}" if retries
      command += " --threads #{threads.to_i}" if threads
      command += " --live" if is_live
      output = File.join(configatron.save_path, output)
      command += " --output #{Shellwords.escape(output)}" if output
      download_dir_check(output)
      pid = exec_command(command, output)
      return pid
    end

    # @param command [String]
    # @return [Boolean]
    def self.exec_command(command, output)
      SleepRoom.info("Call command: #{command}")
      SleepRoom.info("STDOUT: #{output}.out , STDERR: #{output}.err")
      pid = spawn(command, out: "#{output}.out", err: "#{output}.err")
      SleepRoom.info("PID: #{pid}")
      Process.detach(pid)
      return pid
    end

    def self.download_dir_check(output)
      dir = File.dirname(output)
      if !Dir.exist?(dir)
        SleepRoom.info("#{dir} does not exist, creating...")
        SleepRoom.mkdir(dir)
      end
    end
  end
end
