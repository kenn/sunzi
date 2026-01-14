# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = 'sunzi'
  spec.version       = '3.0.0' # retrieve this value by: Gem.loaded_specs['sunzi'].version.to_s
  spec.authors       = ['Kenn Ejima']
  spec.email         = ['kenn.ejima@gmail.com']
  spec.summary       = %q{Server provisioning utility for minimalists}
  spec.description   = %q{Server provisioning utility for minimalists}
  spec.homepage      = 'https://github.com/kenn/sunzi'
  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0").reject {|f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'rainbow', '~> 3.0'
  spec.add_dependency 'net-ssh', '~> 7.0'
  spec.add_dependency 'logger'
  spec.add_dependency 'hashugar'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest', '~> 6.0'
end
