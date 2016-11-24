$:.push File.expand_path('../lib', __FILE__)
require 'clacks/version'

Gem::Specification.new do |s|
  s.name = %q{clacks}
  s.version = Clacks::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['ITRP']
  s.email = %q{developer@itrp.com}
  s.license = 'MIT'
  s.homepage = %q{https://github.com/itrp/clacks}
  s.summary = %q{Clacks system for receiving emails}
  s.description = %q{Clacks system for receiving emails to be processed in ruby}
  s.date = Time.now.utc.strftime('%Y-%m-%d')
  s.files = Dir.glob('lib/**/*') + [
     'MIT-LICENSE',
     'README.md',
     'Gemfile',
     'clacks.gemspec'
  ]
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
  s.rdoc_options = ['--charset=UTF-8']
  s.add_dependency('mail')
  s.add_development_dependency 'rake'
  # s.add_development_dependency 'rcov'
  s.add_development_dependency 'rspec'
end

