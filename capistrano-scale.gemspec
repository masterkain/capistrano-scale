# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-scale/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = 'capistrano-scale'
  gem.version     = CapistranoScale::VERSION.dup
  gem.author      = 'Claudio Poli'
  gem.email       = 'masterkain@gmail.com'
  gem.homepage    = 'https://github.com/masterkain/capistrano-scale'
  gem.summary     = %q{Capistrano deployment strategy that transfers the release on S3}
  gem.description = %q{Capistrano deployment strategy that creates and pushes a tarball into S3, for both pushed deployments and pulled auto-scaling.}

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'capistrano', '>= 2.13.3'
  gem.add_runtime_dependency 'fog'
end