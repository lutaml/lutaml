# frozen_string_literal: true

require "bundler/setup"
require "lutaml/graphviz"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end

def fixtures_path(path)
  File.join(File.expand_path("./fixtures", __dir__), path)
end
