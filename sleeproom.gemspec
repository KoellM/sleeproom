# frozen_string_literal: true

require_relative "lib/sleeproom/version"

Gem::Specification.new do |spec|
  spec.name          = "sleeproom"
  spec.version       = SleepRoom::VERSION
  spec.authors       = ["Koell"]
  spec.email         = ["i@wug.moe"]

  spec.summary       = "sleeproom"
  spec.homepage      = "https://github.com/KoellM/sleeproom"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = ["sleeproom"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency("async", "~> 1.26.0")
  spec.add_runtime_dependency("async-http-faraday", "~> 0.9.0")
  spec.add_runtime_dependency("async-websocket", "~> 0.15.0")
  spec.add_runtime_dependency("colorize", "~> 0.8.0")
  spec.add_runtime_dependency("configatron", "~> 4.5.0")
  spec.add_runtime_dependency("terminal-table", "~> 1.8.0")

  spec.post_install_message = <<~STR
    SleepRoom 需要:
      [Minyami]       https://github.com/Last-Order/minyami
      (npm install -g minyami)
    使用前请确保已安装上述依赖。
  STR
end
