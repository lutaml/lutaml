# frozen_string_literal: true

require "bundler/setup"
require_relative "../lib/lutaml"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def fixtures_path(path)
  File.join(File.expand_path("./fixtures", __dir__), path)
end

def by_name(entries, name)
  entries.detect { |n| n.name == name }
end

def gem_available?(name)
  require name
  true
rescue LoadError
  false
end

RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{elk_layout_spec}) do |metadata|
    metadata[:skip] = "elkrb gem not available" unless gem_available?("elkrb")
  end

  config.define_derived_metadata(file_path: %r{svg_conformance_spec}) do |metadata|
    metadata[:skip] = "svg_conform gem not available" unless gem_available?("svg_conform")
  end
end
