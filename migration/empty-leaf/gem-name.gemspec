# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name        = "<%= gem_name %>"
  s.version     = "1.0.0"
  s.authors       = ["Ribose Inc."]
  s.email         = ["open.source@ribose.com"]

  s.homepage    = "http://github.com/lutaml/lutaml"
  s.summary     = "Lutaml stub gem for <%= gem_name %>"
  s.description = "Lutaml stub gem for <%= gem_name %>"
  s.license       = "BSD-2-Clause"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- exe/*`.split("\n").map do |f|
    File.basename(f)
  end
  s.bindir        = "exe"
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  s.add_dependency "lutaml", "> 0.7.7"
end
