# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "siriproxy-wienhelper"
  s.version     = "0.0.1" 
  s.authors     = ["michael ullrich"]
  s.email       = ["Twitter @muhkuh0815"]
  s.homepage    = ""
  s.summary     = %q{a Siri Proxy Plugin for Vienna - Austria}
  s.description = %q{extended plamonis siriproxy example plugin to search various things in Vienna and shows it as map in Siri, even outside the US. }

  s.rubyforge_project = "siriproxy-wienhelper"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "eat"
  s.add_runtime_dependency "httparty"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "siren"
  #s.add_runtime_dependency "uri"
end
