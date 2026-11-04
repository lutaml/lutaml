# frozen_string_literal: true

desc "Property-based conformance harness over the full corpus " \
     "(parse → format → parse idempotence)"
task :conformance do
  ENV["EXPRESSIR_CONFORMANCE"] = "1"
  sh "bundle exec rspec spec/expressir/express/formatter_roundtrip_conformance_spec.rb"
end

namespace :conformance do
  desc "Measure parse, diagnostic and idempotence rates over the corpus " \
       "and write a JSON trend artifact"
  task :trend do
    require "expressir"

    stepmod = ENV["STEPMOD_DIR"] ||
      File.expand_path("~/src/mn/iso-10303-stepmod")
    corpus = File.join(stepmod, "data/resources")
    files = Dir[File.join(corpus, "**/*.exp")]
      .select { |file| File.size(file) < 250_000 }
    output = ENV["CONFORMANCE_TREND_OUT"] || "conformance-trend.json"
    report = Expressir::Conformance::Trend.run(files, output: output)
    puts "wrote #{output} " \
         "(parse #{report['parse_rate']}, idempotence " \
         "#{report['idempotence_rate']}, diagnostics #{report['diagnostic_rate']})"
  end
end
