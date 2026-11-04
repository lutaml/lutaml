# frozen_string_literal: true

require "lutaml/jsonschema"
require "canon/rspec_matchers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def fixture_path(name)
    File.expand_path(File.join(__dir__, "fixtures", name))
  end
end
