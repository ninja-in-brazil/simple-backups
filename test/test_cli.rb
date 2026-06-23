# frozen_string_literal: true

require "test_helper"

class TestCLI < Minitest::Test
  def test_init_command
    with_temp_dir do
      assert_output(/Created/) { SimpleBackups::CLI.run(%w[init]) }
      assert File.exist?(SimpleBackups::Config::CONFIG_FILENAME)
    end
  end

  def test_backup_command
    with_temp_dir do |dir|
      source = File.join(dir, "notes.txt")
      File.write(source, "content")
      write_config(dir, backup_paths: [source], destination: "backups")

      assert_output(/Backup created/) { SimpleBackups::CLI.run(%w[backup]) }
      assert Dir.glob("backups/test_backup_*").any?
    end
  end

  def test_restore_dry_run_command
    with_temp_dir do |dir|
      source = File.join(dir, "notes.txt")
      File.write(source, "before")
      write_config(dir, backup_paths: [source], destination: "backups")

      SimpleBackups::CLI.run(%w[backup])
      File.write(source, "after")

      output = capture_io do
        SimpleBackups::CLI.run(%w[restore 1 --dry-run --diff])
      end

      assert_includes output[0], "Dry run complete"
      assert_includes output[0], "Would overwrite"
      assert_includes output[0], "Diff for"
      assert_equal "after", File.read(source)
    end
  end

  def test_restore_diff_requires_dry_run
    err = capture_io do
      assert_raises(SystemExit) { SimpleBackups::CLI.run(%w[restore --diff]) }
    end[1]

    assert_includes err, "--diff requires --dry-run"
  end

  def test_unknown_command_exits_with_error
    err = capture_io { assert_raises(SystemExit) { SimpleBackups::CLI.run(%w[unknown]) } }[1]
    assert_includes err, "Unknown command"
  end
end
