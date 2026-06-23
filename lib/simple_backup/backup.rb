# frozen_string_literal: true

require "fileutils"
require "pathname"
require "time"
require "yaml"

module SimpleBackup
  class Backup
    MANIFEST_FILENAME = ".simple_backup_manifest.yml"

    class Error < StandardError; end

    def initialize(config)
      @config = config
    end

    def run!
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      backup_dir = @config.destination_path.join("#{@config.backup_name}_#{timestamp}")
      FileUtils.mkdir_p(backup_dir)

      entries = []
      @config.backup_paths.each do |source_path|
        source = Pathname.new(source_path).expand_path
        raise Error, "Path not found: #{source}" unless source.exist?

        dest_name = source.basename.to_s
        dest = backup_dir.join(dest_name)
        copy_entry(source, dest)
        entries << { "source" => source.to_s, "backup_entry" => dest_name }
      end

      write_manifest(backup_dir, entries)
      backup_dir.to_s
    end

    def restore!(selection: nil, dry_run: false, diff: false, io: $stdout)
      backups = list_backups
      raise Error, "No backups found for '#{@config.backup_name}'" if backups.empty?

      chosen = select_backup(backups, selection: selection)
      manifest = load_manifest(chosen)
      plan = restore_plan(chosen, manifest)

      if dry_run
        print_dry_run(chosen, plan, diff: diff, io: io)
        return chosen.to_s
      end

      plan.each do |operation|
        restore_operation(operation)
      end

      chosen.to_s
    end

    def list_backups
      dest = @config.destination_path
      return [] unless dest.directory?

      prefix = "#{@config.backup_name}_"
      dest.children
          .select(&:directory?)
          .select { |d| d.basename.to_s.start_with?(prefix) }
          .sort_by { |d| d.basename.to_s }
          .reverse
    end

    private

    def restore_plan(backup_dir, manifest)
      manifest.fetch("entries").flat_map do |entry|
        source = Pathname.new(entry.fetch("source"))
        backup_entry = backup_dir.join(entry.fetch("backup_entry"))
        raise Error, "Backup entry missing: #{backup_entry}" unless backup_entry.exist?

        if backup_entry.directory?
          directory_restore_plan(backup_entry, source)
        else
          [file_restore_operation(backup_entry, source)]
        end
      end
    end

    def directory_restore_plan(backup_entry, source)
      operations = []
      operations << { action: :mkdir, backup: backup_entry, target: source } unless source.directory?

      backup_entry.find.each do |path|
        next if path == backup_entry

        relative_path = path.relative_path_from(backup_entry)
        target = source.join(relative_path)

        if path.directory?
          operations << { action: :mkdir, backup: path, target: target } unless target.directory?
        else
          operations << file_restore_operation(path, target)
        end
      end

      operations
    end

    def file_restore_operation(backup_entry, target)
      action = target.exist? ? :overwrite : :copy
      { action: action, backup: backup_entry, target: target }
    end

    def restore_operation(operation)
      case operation[:action]
      when :mkdir
        FileUtils.mkdir_p(operation[:target])
      when :copy, :overwrite
        FileUtils.mkdir_p(operation[:target].dirname)
        FileUtils.cp(operation[:backup].to_s, operation[:target].to_s)
      end
    end

    def print_dry_run(backup_dir, plan, diff:, io:)
      io.puts "Dry run: restoring #{backup_dir.basename}"

      if plan.empty?
        io.puts "No files would be copied."
        return
      end

      plan.each do |operation|
        case operation[:action]
        when :mkdir
          io.puts "Would create directory: #{operation[:target]}"
        when :copy
          io.puts "Would copy: #{operation[:backup]} -> #{operation[:target]}"
        when :overwrite
          io.puts "Would overwrite: #{operation[:target]} with #{operation[:backup]}"
          print_diff(operation, io: io) if diff
        end
      end
    end

    def print_diff(operation, io:)
      current = operation[:target].read
      restored = operation[:backup].read
      return if current == restored

      io.puts "Diff for #{operation[:target]}:"
      io.puts "--- current"
      io.puts "+++ restored"
      io.puts unified_line_diff(current, restored)
    rescue ArgumentError
      io.puts "Diff skipped for #{operation[:target]}: file is not valid text"
    end

    def unified_line_diff(current, restored)
      current_lines = current.lines
      restored_lines = restored.lines
      max = [current_lines.length, restored_lines.length].max
      output = []

      max.times do |index|
        old_line = current_lines[index]
        new_line = restored_lines[index]
        next if old_line == new_line

        output << "-#{old_line}" if old_line
        output << "+#{new_line}" if new_line
      end

      output.join
    end

    def copy_entry(source, dest)
      if source.directory?
        FileUtils.mkdir_p(dest)
        FileUtils.cp_r(source.join(".").to_s, dest.to_s)
      else
        FileUtils.mkdir_p(dest.dirname)
        FileUtils.cp(source.to_s, dest.to_s)
      end
    end

    def write_manifest(backup_dir, entries)
      manifest = {
        "backup_name" => @config.backup_name,
        "created_at" => Time.now.iso8601,
        "entries" => entries
      }
      backup_dir.join(MANIFEST_FILENAME).write(YAML.dump(manifest))
    end

    def load_manifest(backup_dir)
      path = backup_dir.join(MANIFEST_FILENAME)
      raise Error, "Manifest not found in #{backup_dir}" unless path.exist?

      YAML.safe_load(path.read) || {}
    end

    def select_backup(backups, selection: nil)
      return backups[selection.to_i - 1] if selection

      puts "Available backups:"
      backups.each_with_index do |backup, index|
        puts "  #{index + 1}. #{backup.basename}"
      end
      print "Select backup (1-#{backups.size}): "
      choice = $stdin.gets&.strip
      index = choice.to_i
      raise Error, "Invalid selection" if index < 1 || index > backups.size

      backups[index - 1]
    end
  end
end
