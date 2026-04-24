# frozen_string_literal: true

require "bundler/setup"
require_relative "../lib/lutaml"

RSpec.configure do |config|
  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def fixtures_path(path)
  File.join(File.expand_path("./fixtures", __dir__), path)
end

def assets_path(path)
  assets_folder = File.expand_path("./assets", __dir__)
  FileUtils.mkdir_p(assets_folder)
  File.join(assets_folder, path)
end

def by_name(entries, name)
  entries.detect { |n| n.name == name }
end

# Generate a unique temp file path WITHOUT creating or holding a file handle.
# Tempfile.new holds an open handle on Windows which prevents rubyzip's
# File.rename from succeeding (Errno::EACCES).
def temp_lur_path(prefix: "test")
  File.join(Dir.tmpdir, "#{prefix}#{Process.pid}-#{rand(0x1000000).to_s(36)}.lur")
end

Dir[File.expand_path("./support/**/*.rb", __dir__)].each do |f|
  require f
end
