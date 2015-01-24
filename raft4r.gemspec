Gem::Specification.new do |s|
  s.name        = 'raft4r'
  s.version     = '0.0.0'
  s.date        = '2015-01-24'
  s.summary     = "Ruby Raft implementation"
  s.description = "Ruby Raft implementation"
  s.authors     = ["Yuheng Chen"]
  s.email       = 'chyh1990@gmail.com'
  s.homepage    = 'http://rubygems.org/gems/raft4r'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  
  s.add_dependency 'eventmachine'
  s.add_development_dependency 'test-unit', '>=3.0.0'
end
