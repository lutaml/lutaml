source "https://rubygems.org"

# Specify your gem's dependencies in lutaml.gemspec
gemspec

# Pin parsanol to 1.3.9: 1.3.10 pre-compiled platform gems require Ruby >= 3.3,
# causing source gem fallback on Ruby 3.2 Windows where compilation fails.
gem "parsanol", "1.3.9"

gem "lutaml-model", github: "lutaml/lutaml-model", branch: "main"
gem "openssl", "~> 3.0"
gem "rack-test"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"

# Sibling-repo path dependencies — used during local development when
# the sibling checkout exists. In CI and for gem install, fall back to
# published rubygems versions.
%w[canon lutaml-lml lutaml-uml].each do |sibling_gem|
  sibling_path = File.expand_path("../#{sibling_gem}", __dir__)
  if File.directory?(sibling_path)
    gem sibling_gem, path: sibling_path
  else
    gem sibling_gem
  end
end
