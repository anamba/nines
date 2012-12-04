$:.push File.expand_path("../lib", __FILE__)
require "nines/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'nines'
  s.version     = Nines::VERSION
  s.summary     = 'Simple server monitoring tool written in pure Ruby.'
  s.description = 'Nines is a simple server monitoring tool written in Ruby.'

  s.required_ruby_version     = '>= 1.9.3'
  s.required_rubygems_version = '>= 1.8.11'

  s.author      = "Aaron Namba"
  s.email       = "aaron@biggerbird.com"
  s.homepage    = "https://github.com/anamba/nines"
  s.license     = 'MIT'

  s.bindir      = 'bin'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'net-ping',     '~> 1.5.3'
  s.add_dependency 'dnsruby',      '~> 1.53'
  s.add_dependency 'mail',         '~> 2.4'
  s.add_dependency 'trollop',      '~> 2.0'
end
