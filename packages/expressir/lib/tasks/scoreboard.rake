# frozen_string_literal: true

require "rake"
require "rspec/core/rake_task"

desc "Print the per-command scoreboard (CPU medians, interleaved)"
task scoreboard: :compile do
  require "expressir"
  require "expressir/scoreboard"
  puts Expressir::Scoreboard.table(Expressir::Scoreboard.run)
end

namespace :scoreboard do
  desc "Print the scoreboard"
  task print: :compile do
    require "expressir"
    require "expressir/scoreboard"
    rows = Expressir::Scoreboard.run
    puts Expressir::Scoreboard.table(rows)
    if (path = ENV.fetch("SCOREBOARD_JSON", nil))
      File.write(path, JSON.generate(rows))
    end
  end

  # The local baseline is machine-specific; CI points the same gate at
  # its own committed measurement (see .github/workflows/performance-release.yml).
  baseline_path = ENV.fetch("SCOREBOARD_BASELINE", "scoreboard-baseline.json")

  desc "Update the committed scoreboard baseline"
  task update: :compile do
    require "expressir"
    require "expressir/scoreboard"
    File.write(baseline_path,
               "#{JSON.pretty_generate(Expressir::Scoreboard.run)}\n")
    puts "baseline written to #{baseline_path}"
  end

  desc "Gate: fail when a command regresses over 2x the baseline (medians swing on loaded boxes)"
  task gate: :compile do
    require "expressir"
    require "expressir/scoreboard"
    unless File.exist?(baseline_path)
      abort "no scoreboard baseline at #{baseline_path} — " \
            "run rake scoreboard:update (or set SCOREBOARD_BASELINE) first"
    end

    baseline = JSON.parse(File.read(baseline_path))
    current = Expressir::Scoreboard.run
    regressions = current.filter_map do |row, cpu|
      base = baseline[row]
      next if base.nil? || base.zero?

      "#{row}: #{format('%.4f', cpu)} vs baseline #{format('%.4f', base)}" if cpu > base * 2.0
    end
    abort "scoreboard regressions:\n#{regressions.join("\n")}" if regressions.any?

    puts "scoreboard: no regressions over the baseline"
  end
end
