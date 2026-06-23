# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "simple_backups"

module SimpleBackups
  module TestHelpers
    def with_temp_dir
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { yield dir }
      end
    end

    def write_config(dir, backup_name: "test_backup", backup_paths: [], destination: "backups")
      paths = backup_paths.map { |p| "  - #{p}" }.join("\n")
      File.write(
        File.join(dir, SimpleBackups::Config::CONFIG_FILENAME),
        <<~YAML
          backup_name: #{backup_name}
          backup_paths:
          #{paths}
          destination: #{destination}
        YAML
      )
    end
  end
end

class Minitest::Test
  include SimpleBackups::TestHelpers
end
