source "https://rubygems.org"

# Specify your gem's dependencies in lutaml.gemspec
gemspec

gem "openssl", "~> 3.0"
gem "rack-test"
gem "rake"
gem "rspec"

# Override gemspec deps with sibling paths or GitHub during local
# development. In CI these don't resolve and bundler uses the gemspec's
# own add_dependency declarations against rubygems.
sibling_overrides = %w[canon lutaml-lml lutaml-uml]
sibling_overrides.each do |sibling_gem|
  sibling_path = File.expand_path("../#{sibling_gem}", __dir__)
  gem sibling_gem, path: sibling_path if File.directory?(sibling_path)
end

github_override = File.expand_path("../lutaml-model", __dir__)
if File.directory?(github_override)
  gem "lutaml-model", path: github_override
end
