# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop perf frontend:audit]

namespace :perf do
  desc "Pipeline performance harness with regression caps (TODO.sota/08)"
  task :profile do
    ruby "benchmark/pipeline_profile.rb"
  end
end

desc "Run the pipeline performance regression gate"
task perf: "perf:profile"

namespace :frontend do
  desc "Build the Vue frontend"
  task :build do
    Dir.chdir(File.expand_path("frontend", __dir__)) do
      sh "npm install"
      sh "npm run build"
    end
  end

  desc "axe-core accessibility audit of the generated SPA (needs Chrome)"
  task :audit do
    ruby "script/axe_audit"
  end
end

task :build_frontend do
  Rake::Task["frontend:build"].invoke
end
