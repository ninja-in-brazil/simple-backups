# frozen_string_literal: true

require "stringio"
require "test_helper"

class TestBackup < Minitest::Test
  def test_run_creates_timestamped_backup_with_manifest
    with_temp_dir do |dir|
      source = File.join(dir, "data.txt")
      File.write(source, "hello")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      backup_path = SimpleBackup::Backup.new(config).run!

      assert_match(/\A#{Regexp.escape(dest_dir)}\/test_backup_\d{8}_\d{6}\z/, backup_path)
      backup = Pathname.new(backup_path)
      assert backup.join("data.txt").exist?
      assert backup.join(SimpleBackup::Backup::MANIFEST_FILENAME).exist?

      manifest = YAML.safe_load(backup.join(SimpleBackup::Backup::MANIFEST_FILENAME).read)
      assert_equal 1, manifest["entries"].size
      assert_equal source, manifest["entries"][0]["source"]
    end
  end

  def test_run_copies_directory_contents
    with_temp_dir do |dir|
      source = File.join(dir, "data")
      nested = File.join(source, "nested")
      FileUtils.mkdir_p(nested)
      File.write(File.join(source, "root.txt"), "root")
      File.write(File.join(nested, "child.txt"), "child")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      backup_path = SimpleBackup::Backup.new(config).run!

      backup = Pathname.new(backup_path)
      assert_equal "root", backup.join("data", "root.txt").read
      assert_equal "child", backup.join("data", "nested", "child.txt").read
    end
  end

  def test_restore_copies_files_back
    with_temp_dir do |dir|
      source = File.join(dir, "data.txt")
      File.write(source, "original")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      SimpleBackup::Backup.new(config).run!

      File.write(source, "modified")
      SimpleBackup::Backup.new(config).restore!(selection: "1")

      assert_equal "original", File.read(source)
    end
  end

  def test_restore_dry_run_reports_copy_and_overwrite
    with_temp_dir do |dir|
      source = File.join(dir, "data.txt")
      File.write(source, "original")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      SimpleBackup::Backup.new(config).run!
      File.write(source, "modified")

      output = StringIO.new
      SimpleBackup::Backup.new(config).restore!(selection: "1", dry_run: true, io: output)

      assert_includes output.string, "Would overwrite: #{source}"
      assert_equal "modified", File.read(source)
    end
  end

  def test_restore_dry_run_diff_shows_changes
    with_temp_dir do |dir|
      source = File.join(dir, "data.txt")
      File.write(source, "original")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      SimpleBackup::Backup.new(config).run!
      File.write(source, "modified")

      output = StringIO.new
      SimpleBackup::Backup.new(config).restore!(
        selection: "1",
        dry_run: true,
        diff: true,
        io: output
      )

      assert_includes output.string, "Diff for #{source}:"
      assert_includes output.string, "-modified"
      assert_includes output.string, "+original"
    end
  end

  def test_list_backups_filters_by_name
    with_temp_dir do |dir|
      source = File.join(dir, "file.txt")
      File.write(source, "x")
      dest_dir = File.join(dir, "backups")
      write_config(dir, backup_name: "alpha", backup_paths: [source], destination: dest_dir)

      config = SimpleBackup::Config.load!
      backup = SimpleBackup::Backup.new(config)
      backup.run!

      write_config(dir, backup_name: "beta", backup_paths: [source], destination: dest_dir)
      config_beta = SimpleBackup::Config.load!
      SimpleBackup::Backup.new(config_beta).run!

      backups = backup.list_backups
      assert_equal 1, backups.size
      assert backups[0].basename.to_s.start_with?("alpha_")
    end
  end
end
