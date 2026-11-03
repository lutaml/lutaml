# frozen_string_literal: true

require "bundler/gem_tasks"
require "open3"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :deps do
  desc "Fail when Gemfile.lock resolution drifts from Gemfile/gemspec"
  task :lockfile_check do
    fresh, status = Bundler.with_unbundled_env do
      Open3.capture2("bundle", "lock", "--print")
    end
    unless status.success? && !fresh.empty?
      abort("deps:lockfile_check failed: could not resolve the Gemfile")
    end
    committed = File.exist?("Gemfile.lock") ? File.read("Gemfile.lock") : ""

    signature = lambda do |text|
      parsed = Bundler::LockfileParser.new(text)
      {
        dependencies: parsed.dependencies.keys.sort,
        # name→version only: platform variant/listing noise differs
        # across environments (and bundler generations) and is not the
        # behavior contract we guard.
        versions: parsed.specs.map do |s|
          "#{s.name} #{s.version}"
        end.uniq.sort,
      }
    end

    fresh_sig = signature.call(fresh)
    committed_sig = signature.call(committed)

    if fresh_sig != committed_sig
      deltas = fresh_sig.keys.flat_map do |key|
        (fresh_sig[key] - committed_sig[key]).map { |v| "fresh-only #{key}: #{v}" } +
          (committed_sig[key] - fresh_sig[key]).map { |v| "lock-only #{key}: #{v}" }
      end
      warn <<~MSG
        Gemfile.lock is out of sync with the current Gemfile/gemspec.
        A fresh resolution differs from the committed lockfile — run
        `bundle install` locally and commit the updated Gemfile.lock.
        (Unlocked CI resolutions have shipped silent dependency behavior
        changes before, e.g. rng 0.3.8; the lockfile is the contract.)
      MSG
      deltas.first(20).each { |line| warn "  #{line}" }
      abort("deps:lockfile_check failed")
    end
  end
end

task default: %i[deps:lockfile_check spec rubocop]

namespace :conformance do
  desc "Run the conformance corpus and write tmp/conformance_report.md"
  task :run do
    require "lutaml/xsd"
    require_relative "lib/lutaml/xsd/conformance/runner"

    runner = Lutaml::Xsd::Conformance::Runner.new(
      File.join(__dir__, "spec", "conformance", "cases"),
    )
    results = runner.run
    report = runner.report(results)
    puts report
    FileUtils.mkdir_p(File.join(__dir__, "tmp"))
    File.write(File.join(__dir__, "tmp", "conformance_report.md"),
               "# Conformance report\n\n```\n#{report}\n```\n")
  end
end

desc "Run the conformance suite"
task conformance: "conformance:run"

namespace :conformance do
  desc "Run the pipeline over the official W3C suite instance tests"
  task w3c: "conformance:w3c:run"

  namespace :w3c do
    desc "Clone the official W3C XML Schema Test Suite into vendor/xsdtests"
    task :setup do
      require "lutaml/xsd"
      require_relative "lib/lutaml/xsd/conformance/w3c_suite"
      Lutaml::Xsd::Conformance::W3CSuite.set_up!
      puts "vendored #{Lutaml::Xsd::Conformance::W3CSuite.vendor_dir}"
    end

    desc "Run the pipeline over the official W3C suite instance tests"
    task run: "conformance:w3c:setup" do
      # One process per batch: lutaml-model's global schema cache grows
      # per parse and the full suite OOMs a single invocation.
      require "lutaml/xsd"
      require "json"
      require_relative "lib/lutaml/xsd/conformance/w3c_suite"
      total = Lutaml::Xsd::Conformance::W3CSuite.cases.size
      batch = 50
      status = []
      (0...total).step(batch) do |offset|
        ok = system(
          RbConfig.ruby, "-Ilib", "-e",
          "require 'lutaml/xsd'; " \
          "require 'lutaml/xsd/conformance/w3c_suite'; " \
          "require 'json'; " \
          "r = Lutaml::Xsd::Conformance::W3CSuite.measure(" \
          "offset: #{offset}, limit: #{batch}); " \
          "r[:failures] = r[:failures].map { |f| " \
          "{ name: f.name, expected: f.expected, " \
          "contributor: f.contributor } }; " \
          "File.write(File.join('tmp', " \
          "'w3c_batch_#{format('%05d', offset)}.json'), JSON.generate(r))"
        )
        status << "#{offset}: #{ok ? 'ok' : 'CRASHED'}"
      end
      puts "batches: #{status.join(', ')}"
    end
  end
end

namespace :benchmark do
  desc "Benchmark leptris vs nokogiri through Moxml on a real corpus"
  task :engines do
    %w[leptris nokogiri].each do |adapter|
      puts
      sh({ "ADAPTER" => adapter }, "bundle exec ruby benchmark/engines.rb")
    end
  end
end

# Build the frontend SPA (frontend/dist/)
desc "Build frontend SPA assets"
task :build_frontend do
  frontend_dir = File.join(__dir__, "frontend")
  File.join(frontend_dir, "dist")

  puts "Building frontend..."
  system("cd #{frontend_dir} && npm install && npm run build") || raise("Frontend build failed")
end

# Hook into bundler's release task to ensure frontend is built
Rake::Task["release"].enhance(["build_frontend"])
