# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongo_oplog_backup/version'

Gem::Specification.new do |spec|
  spec.name          = "mongo-oplog-backup"
  spec.version       = MongoOplogBackup::VERSION
  spec.authors       = ["Ralf Kistner"]
  spec.email         = ["ralf@journeyapps.com"]
  spec.summary       = %q{Incremental backups for MongoDB using the oplog.}
  spec.description   = %q{Periodically backup new sections of the oplog for incremental backups.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "bson", "~> 3.2"
  spec.add_dependency "slop", "~> 3.6"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0.0"
  spec.add_development_dependency "mongo", "~> 2.0"
  spec.add_development_dependency "timecop", "~> 0.9.1"
end
