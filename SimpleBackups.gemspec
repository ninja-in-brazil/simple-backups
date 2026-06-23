# frozen_string_literal: true

require_relative "lib/simple_backups/version"

Gem::Specification.new do |spec|
  spec.name          = "SimpleBackups"
  spec.version       = SimpleBackups::VERSION
  spec.authors       = ["SimpleBackups"]
  spec.email         = ["noreply@example.com"]

  spec.summary       = "Simple backups via simple-backup CLI"
  spec.description   = "Initialize, backup, and restore files with a YAML config"
  spec.homepage      = "https://github.com/ninja-in-brazil/simple-backups"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    %w[
      README.md
      SimpleBackups.gemspec
      exe/simple-backup
      lib/simple_backups.rb
      lib/simple_backups/backup.rb
      lib/simple_backups/cli.rb
      lib/simple_backups/config.rb
      lib/simple_backups/version.rb
    ].select { |file| File.file?(file) }
  end

  spec.bindir        = "exe"
  spec.executables   = ["simple-backup"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
end
