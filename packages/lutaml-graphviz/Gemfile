# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Until the lutaml monogem (with LML) ships, develop against a sibling checkout.
lutaml = File.expand_path("../lutaml", __dir__)
gem "lutaml", path: lutaml if File.directory?(lutaml)

gem "rake"
gem "rspec"
gem "rubocop"
