# frozen_string_literal: true

require "configatron"
require "colorize"
require "fileutils"
require "yaml"
require "logger"

module SleepRoom
  class Error < StandardError; end
  # @return [String]
  def self.root_path
    Dir.pwd
  end

  # @return [String]
  def self.user_path
    Dir.home
  end

  # @return [String]
  def self.sleeproom_dir
    File.join(user_path, "sleeproom")
  end

  def self.working_dir
    Dir.pwd
  end

  # @return [String]
  def self.config_dir
    File.join(user_path, ".config", "sleeproom")
  end

  # @param filename [String]
  # @return [String]
  def self.config_path(config)
    name = {
      status: "status.yml",
      base: "base.yml",
      record: "record.yml",
      pid: "tmp/pid.yml"
    }
    file = name[config].to_s
    raise Error if file.empty?
    return File.join(config_dir, file) if config == :base

    if load_config(:base)[:config_path] == "USER_CONFIG"
      File.join(config_dir, file)
    else
      File.join(load_config(:base)[:config_path], file)
    end
  end

  # @param filename [Symbol]
  # @param settings [Hash]
  # @return [Boolean]
  def self.write_config_file(config, settings)
    file = File.new(config_path(config), "w")
    file.puts(YAML.dump(settings))
    file.close
  end

  def self.create_config_file(config, settings)
    path = config_path(config)
    return false if File.exist?(path)

    mkdir(File.dirname(path)) unless Dir.exist?(File.dirname(path))
    write_config_file(config, settings)
  end

  def self.load_config(config)
    raise Error if config.empty? || !File.exist?(config_path(config))

    YAML.load_file(config_path(config))
  rescue Error => e
    init_config
    retry
  end

  def self.mkdir(path)
    FileUtils.mkdir_p(path) unless Dir.exist?(path)
  end

  def self.init_base
    base = {
      web: {
        use: true,
        server: "localhost",
        port: 3000
      },
      proxy: {
        use: false,
        server: "localhost",
        port: 8080,
        type: "socks5"
      },
      record: {
        all: true,
        wanted: [],
        unwanted: []
      },
      config_path: "USER_CONFIG",
      save_path: "#{sleeproom_dir}/archive",
      working_path: "#{sleeproom_dir}/working",
      default_save_name: "%ROOMNAME%-%TIME%.ts",
      minyami: {
        threads: 8,
        retries: 999
      },
      logger: {
        console: true,
        file: {
          use: false,
          path: "#{sleeproom_dir}/log"
        }
      }
    }
    create_config_file(:base, base)
  end

  def self.init_config
    mkdir(config_dir) unless Dir.exist?(config_dir)

    mkdir("#{config_dir}/tmp") unless Dir.exist?("#{config_dir}/tmp")

    init_base

    record = {
      "default" => []
    }

    create_config_file(:record, record)
    create_config_file(:status, [])
    write_config_file(:pid, nil)
  end

  # @return [Boolean]
  def self.reload_config
    configs = %i[base]
    configs.each do |config|
      configatron.configure_from_hash(YAML.load_file(config_path(config)))
    end
    true
  rescue Errno::ENOENT => e
    info("Creating configuration...")
    init_base
    false
  end

  def self.settings
    configatron
  end

  def self.load_status
    SleepRoom.load_config(:status)
  rescue Error
    create_status
    retry
  end

  def self.load_pid
    SleepRoom.load_config(:pid)
  rescue Error
    create_pid(nil)
    retry
  end

  def self.running?(pid = nil)
    pid = SleepRoom.load_config(:pid) if pid.nil?
    Process.kill(0, pid)
    true
  rescue StandardError
    false
  end

  def self.load_record
    SleepRoom.load_config(:record)
  rescue Error
    create_record
    retry
  end

  def self.create_status(status = [])
    SleepRoom.create_config_file(:status, status)
  end

  def self.create_record(record = { default: [] })
    SleepRoom.create_config_file(:record, record)
  end

  def self.create_pid(pid)
    SleepRoom.create_config_file(:pid, pid)
    SleepRoom.write_config_file(:pid, pid)
  end
  
  def self.find_tmp_directory(output, call_time)
    regex = /Proccessing (.*) finished./
    output = File.join(configatron.save_path, output)
    log = "#{output}.out"
    if media_name = File.readlines(log).select { |line| line =~ regex }.last.match(regex)[1]
      directories = Dir["/tmp/minyami#{call_time.to_i / 10}*"]
      directories.each do |path|
        if Dir.glob("#{path}/*.ts").select{ |e| e.include?("media_970.ts")}
          next if !Dir.glob("#{path}/*.ts").last.include?("media_970.ts")
          return path
        end
      end
    end
  end

  def self.move_ts_to_archive(path)
    archive_path = File.dirname(path)
    FileUtils.cp_r(path, archive_path)
  rescue => e
    p e
    SleepRoom.error("复制失败.")
  end

  # @param string [String]
  # @return [nil]
  def self.info(string)
    log(:info, string)
  end

  # @param string [String]
  # @return [nil]
  def self.warning(string)
    log(:warning, string)
  end

  # @param string [String]
  # @return [nil]
  def self.error(string)
    log(:error, string)
  end

  def self.log(type, log)
    if configatron.logger.console == true
      case type
      when :info
        puts("[INFO] #{log}".colorize(:white))
      when :warning
        warn("[WARN] #{log}".colorize(:yellow))
      when :error
        puts("[ERROR] #{log}".colorize(:red))
      end
    end
    file_logger(type, log) if configatron.logger.file.use == true
  end

  def self.file_logger(type, log)
    path = configatron.logger.file.path
    mkdir(File.dirname(path)) unless Dir.exist?(File.dirname(path))
    logger = Logger.new(path)
    case type
    when :info
      logger.info(log)
    when :warning
      logger.warning(log)
    when :error
      logger.error(log)
    end
  end
end
