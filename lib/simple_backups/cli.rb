# frozen_string_literal: true

module SimpleBackups
  class CLI
    COMMANDS = %w[init backup restore].freeze

    def self.run(argv)
      new.run(argv)
    end

    def run(argv)
      command = argv.first
      if command.nil? || command == "--help" || command == "-h"
        print_usage
        exit command.nil? ? 1 : 0
      end

      unless COMMANDS.include?(command)
        $stderr.puts "Unknown command: #{command}"
        print_usage
        exit 1
      end

      send(command, argv[1..])
    rescue Config::Error, Backup::Error => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    private

    def init(_args)
      path = Config.init!
      puts "Created #{path}"
    end

    def backup(_args)
      config = Config.load!
      backup_dir = Backup.new(config).run!
      puts "Backup created at #{backup_dir}"
    end

    def restore(args)
      options = parse_restore_options(args)
      config = Config.load!
      restored = Backup.new(config).restore!(
        selection: options[:selection],
        dry_run: options[:dry_run],
        diff: options[:diff]
      )

      if options[:dry_run]
        puts "Dry run complete for #{restored}"
      else
        puts "Restored from #{restored}"
      end
    end

    def parse_restore_options(args)
      dry_run = false
      diff = false
      selection = nil
      unknown = []

      args.each do |arg|
        case arg
        when "--dry-run", "-n"
          dry_run = true
        when "--diff"
          diff = true
        when /\A\d+\z/
          selection ||= arg
        else
          unknown << arg
        end
      end

      raise Backup::Error, "Unknown restore options: #{unknown.join(', ')}" unless unknown.empty?
      raise Backup::Error, "--diff requires --dry-run" if diff && !dry_run

      { dry_run: dry_run, diff: diff, selection: selection }
    end

    def print_usage
      puts <<~USAGE
        Usage: simple-backup <command>

        Commands:
          init     Create config.yml in the current directory
          backup   Copy configured paths to a timestamped backup folder
          restore  List backups and restore one interactively

        Restore options:
          --dry-run, -n   Preview files that would be copied or overwritten
          --diff          Show unified diffs for files that would be overwritten
      USAGE
    end
  end
end
