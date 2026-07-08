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

# Override gemspec deps with sibling paths during local development.
# When siblings don't exist (CI, gem install), the gemspec's own
# add_dependency declarations handle resolution — don't duplicate them
# here (causes bundler circular loop).
%w[canon lutaml-lml lutaml-uml].each do |sibling_gem|
  sibling_path = File.expand_path("../#{sibling_gem}", __dir__)
  gem sibling_gem, path: sibling_path if File.directory?(sibling_path)
end
