# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sunzi/version"

Gem::Specification.new do |s|
  s.name        = "sunzi"
  s.version     = Sunzi::VERSION
  s.authors     = ["Kenn Ejima"]
  s.email       = ["kenn.ejima@gmail.com"]
  s.homepage    = "http://github.com/kenn/sunzi"
  s.summary     = %q{Server provisioning tool for minimalists}
  s.description = %q{Server provisioning tool for minimalists}

  s.rubyforge_project = "sunzi"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "thor"
end
