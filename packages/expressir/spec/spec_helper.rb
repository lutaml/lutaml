$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# windows stall watchdog (#487): the rake matrix has hung for 6h at
# some point after the first examples, on every engine (native and
# pure-Ruby both stall), and the runner line-buffers rspec's dot
# output - so the hang site is invisible mid-run. Dump every thread's
# stack to stderr (unbuffered) after 20 idle minutes and exit; stderr
# reaches the log immediately.
if Gem.win_platform?
  $spec_last_progress = Time.now
  Thread.new do
    loop do
      sleep 60
      next unless Time.now - $spec_last_progress > 1200

      warn "WATCHDOG: no example progress for 20 min - thread dump follows"
      Thread.list.reject { |t| t == Thread.current }.each_with_index do |t, i|
        warn "--- thread #{i} #{t.name} status=#{t.status}"
        (t.backtrace || []).first(40).each { |line| warn "    #{line}" }
      end
      warn "WATCHDOG: exiting 3"
      Process.exit!(3)
    end
  end
end

require "bundler/setup"
require "expressir"
require "yaml"
require "canon"

Dir["./spec/support/**/*.rb"].each { |file| require file }

RSpec.configure do |config|
  config.after { |__example| $spec_last_progress = Time.now if $spec_last_progress }
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"
  config.include Expressir::ConsoleHelper
  config.include Expressir::ModelElementSpecHelper

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Checks that parse a production-scale schema. They cost about a minute, so
  # `rake verify:remarks` runs them rather than the default suite.
  if ENV["EXPRESSIR_PRODUCTION_SCALE"].to_s.empty?
    config.filter_run_excluding :production_scale
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |ex|
    ex.run
  rescue Expressir::Error => e
    # rubocop:disable all
    puts "Got Expressir::Error: #{e.inspect}."
    if e.backtrace
      puts e.backtrace
    end
    # rubocop:enable all
    raise
  end
end

require "lutaml/model"
Lutaml::Model::Config.configure do |config|
  config.json_adapter_type = :standard
  # Pin the YAML adapter so golden-file specs do not depend on whether
  # the optional yeptris engine is in the bundle (its output omits the
  # leading "---" document marker that Psych emits).
  config.yaml_adapter_type = :standard
end
