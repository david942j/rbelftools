lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require 'elftools/version'

Gem::Specification.new do |s|
  s.name        = 'elftools'
  s.version     = ::ELFTools::VERSION
  s.date        = Date.today.to_s
  s.summary     = 'ELFTools - Pure ruby library for parsing and patching ELF files'
  s.description = <<-EOS
  A light weight ELF parser. elftools is designed to be a low-level ELF parser.
  Inspired by https://github.com/eliben/pyelftools.
  EOS
  s.authors     = ['david942j']
  s.email       = ['david942j@gmail.com']
  s.files       = Dir['lib/**/*.rb'] + %w(README.md)
  s.homepage    = 'https://github.com/david942j/rbelftools'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 2.4'

  s.add_runtime_dependency 'bindata', '~> 2'

  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.7'
  s.add_development_dependency 'rubocop', '~> 1'
  s.add_development_dependency 'simplecov', '~> 0.17', '< 0.22'
  s.add_development_dependency 'yard', '~> 0.9'
end
