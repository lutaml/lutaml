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

Dir[File.expand_path("./support/**/*.rb", __dir__)].each do |f|
  require f
end
