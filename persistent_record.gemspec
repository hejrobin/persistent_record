# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'persistent_record/version'

Gem::Specification.new do |spec|

  spec.name          = "persistent_record"
  spec.version       = PersistentRecord::VERSION
  spec.authors       = ["Robin Grass"]
  spec.email         = ["hej@carbin.se"]
  spec.description   = %q{Introduces soft deletions for ActiveRecord.}
  spec.summary       = %q{Introduces soft deletions for ActiveRecord.}
  spec.homepage      = "http://github.com/lessthanthree/persistent_record"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 5.0", ">= 5.0.1"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

end
