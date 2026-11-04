# frozen_string_literal: true

require "liquid"
require "lutaml/xsd"
require "canon"

# Block network calls in tests — return nil so import resolution is gracefully
# skipped instead of raising and killing the whole parse.
Net::HTTP.define_singleton_method(:get) do |*_args|
  nil
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Helper to create a writable temp directory for tests that need to create zip archives.
# On Windows, Dir.mktmpdir creates directories with restricted permissions that prevent
# RubyZip from writing files. This helper creates the directory in the current working
# directory instead, which avoids the permission issues.
def with_writable_temp_dir
  require "fileutils"

  test_dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
  FileUtils.mkdir_p(test_dir)
  yield test_dir
ensure
  FileUtils.rm_rf(test_dir) if test_dir && File.exist?(test_dir)
end
