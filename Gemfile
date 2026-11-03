# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Until the lml split ships, develop against a sibling lutaml-lml checkout.
lml = File.expand_path("../lutaml-lml", __dir__)
gem "lutaml-lml", path: lml if File.directory?(lml)

gem "rake"
gem "rspec"
gem "rubocop"
