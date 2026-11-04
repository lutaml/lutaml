# frozen_string_literal: true

require "bundler/gem_tasks"

# Dev-tool tasks are optional: the rake-compiler-dock bundle carries
# production dependencies only, and cross-gem builds must still load
# the Rakefile.
begin
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

begin
  require "rubocop/rake_task"

  RuboCop::RakeTask.new
rescue LoadError
end

task default: %i[spec rubocop]

begin
  require "yard"

  YARD::Rake::YardocTask.new
rescue LoadError
end

Dir.glob(File.expand_path("lib/tasks/*.rake", __dir__)).each { |task| load task }

desc "Regenerate the EXPRESS grammar JSON embedded in expressir-rs"
task :"expressir:grammar:dump" do
  require "expressir/express/grammar/parser"
  json = Expressir::Express::Grammar::Parser.cached_grammar_json
  dir = ENV.fetch("EXPRESSIR_RS_DIR", File.expand_path("../expressir-rs", __dir__))
  path = File.join(dir, "assets", "express-grammar.json")
  File.write(path, "#{json}\n")
  puts "wrote #{path}"
end
