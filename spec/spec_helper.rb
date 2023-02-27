require "bundler/setup"
require "lutaml"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

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
