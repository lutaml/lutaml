# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
end

desc 'Compile grammar/lml.parg to the shipped grammar artifact'
task :parg do
  require 'parsanol'
  require 'parsanol/parg'
  require 'json'

  source = File.expand_path('lib/lutaml/lml/grammar/lml.parg', __dir__)
  target = File.expand_path('lib/lutaml/lml/grammar/lml.artifact.json', __dir__)
  document = Parsanol::PARG::Parser.new(File.read(source)).parse
  envelope = Parsanol::PARG::Compiler.compile(document).envelope
  File.write(target, "#{JSON.pretty_generate(envelope)}\n")
  puts "Wrote #{target} (grammar #{envelope.fetch('grammar')}, " \
       "version #{envelope.fetch('version')})"
end

desc 'RuboCop ratchet: files changed vs the base carry no offenses'
task :rubocop_ratchet do
  base = ENV.fetch('RUBOCOP_RATCHET_BASE', 'origin/main')
  ruby_files = ->(f) { (f.end_with?('.rb') || f == 'Rakefile') && File.exist?(f) }
  changed = `git diff --name-only #{base}...HEAD`.split.select(&ruby_files)
  next if changed.empty?

  sh "bundle exec rubocop --force-exclusion #{changed.join(' ')}" do |ok, _res|
    unless ok
      abort "rubocop ratchet failed — new offenses on:
  #{changed.join("\n  ")}"
    end
  end
end
task default: %i[spec rubocop_ratchet]
