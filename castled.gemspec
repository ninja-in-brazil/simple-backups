# frozen_string_literal: true

require_relative "lib/simple_backup/version"

Gem::Specification.new do |spec|
  spec.name          = "castled"
  spec.version       = SimpleBackup::VERSION
  spec.authors       = ["Castled"]
  spec.email         = ["noreply@example.com"]

  spec.summary       = "Simple backups via castled CLI"
  spec.description   = "Initialize, backup, and restore files with a YAML config"
  spec.homepage      = "https://github.com/Macron1-Automations/simple-backup"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    %w[
      README.md
      castled.gemspec
      exe/castled
      lib/simple_backup.rb
      lib/simple_backup/backup.rb
      lib/simple_backup/cli.rb
      lib/simple_backup/config.rb
      lib/simple_backup/version.rb
    ].select { |file| File.file?(file) }
  end

  spec.bindir        = "exe"
  spec.executables   = ["castled"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
end
