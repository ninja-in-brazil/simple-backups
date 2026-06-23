# frozen_string_literal: true

require "yaml"
require "pathname"

module SimpleBackup
  class Config
    CONFIG_FILENAME = "config.yml"

    DEFAULT_TEMPLATE = <<~YAML
      backup_name: omarchy
      backup_paths:
        - ~/.bash_logout
        - ~/.bash_profile
        - ~/.bashrc
        - ~/.gemrc
        - ~/.XCompose
      destination: /run/media/leonid/250GB/backups
    YAML

    class Error < StandardError; end

    attr_reader :backup_name, :backup_paths, :destination

    def self.init!(dir: Dir.pwd)
      path = Pathname.new(dir).join(CONFIG_FILENAME)
      raise Error, "#{CONFIG_FILENAME} already exists" if path.exist?

      path.write(DEFAULT_TEMPLATE)
      path.to_s
    end

    def self.load!(dir: Dir.pwd)
      path = Pathname.new(dir).join(CONFIG_FILENAME)
      raise Error, "#{CONFIG_FILENAME} not found. Run `simple-backup init` first." unless path.exist?

      new(path)
    end

    def initialize(path)
      @path = Pathname.new(path)
      data = YAML.safe_load(@path.read, permitted_classes: [Symbol], aliases: true) || {}
      @backup_name = data["backup_name"] || data[:backup_name]
      @backup_paths = Array(data["backup_paths"] || data[:backup_paths])
      @destination = data["destination"] || data[:destination]
      validate!
    end

    def destination_path
      Pathname.new(@destination).expand_path
    end

    private

    def validate!
      raise Error, "backup_name is required" if @backup_name.nil? || @backup_name.to_s.strip.empty?

      if @backup_paths.empty?
        raise Error, "backup_paths must list at least one file or folder"
      end

      if @destination.nil? || @destination.to_s.strip.empty?
        raise Error, "destination is required"
      end
    end
  end
end
