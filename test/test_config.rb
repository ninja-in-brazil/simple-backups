# frozen_string_literal: true

require "test_helper"

class TestConfig < Minitest::Test
  def test_init_creates_config_yml
    with_temp_dir do |dir|
      path = SimpleBackup::Config.init!
      assert File.exist?(path)
      assert_includes File.read(path), "backup_name:"
      assert_includes File.read(path), "backup_paths:"
      assert_includes File.read(path), "destination:"
    end
  end

  def test_init_refuses_overwrite
    with_temp_dir do
      SimpleBackup::Config.init!
      assert_raises(SimpleBackup::Config::Error) { SimpleBackup::Config.init! }
    end
  end

  def test_load_validates_required_keys
    with_temp_dir do |dir|
      File.write(File.join(dir, SimpleBackup::Config::CONFIG_FILENAME), "backup_paths: []\n")
      assert_raises(SimpleBackup::Config::Error) { SimpleBackup::Config.load! }
    end
  end

  def test_load_reads_config
    with_temp_dir do |dir|
      write_config(dir, backup_paths: ["."], destination: "dest")
      config = SimpleBackup::Config.load!
      assert_equal "test_backup", config.backup_name
      assert_equal ["."], config.backup_paths
      assert_equal Pathname.new("dest").expand_path, config.destination_path
    end
  end
end
