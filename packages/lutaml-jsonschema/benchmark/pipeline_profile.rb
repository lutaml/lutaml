# frozen_string_literal: true

# Pipeline performance harness (TODO.sota/08).
#
# Measures the two budgeted paths on the real-world heroku.json fixture:
#   - Schema.from_json (model construction)
#   - end-to-end SPA generation (SchemaSet + SpaBuilder + inlined HTML)
#
# Metrics are reported both absolutely and as a ratio to a stdlib
# JSON.parse of the same document. The ratio is the machine-independent
# signal: CI runners vary wildly in absolute speed, but the C parser is
# a stable per-machine yardstick. Regression caps apply to the ratio.
#
# Usage: bundle exec ruby benchmark/pipeline_profile.rb [runs]

require "benchmark"
require "json"
require "lutaml/jsonschema"
require "tmpdir"

FIXTURES = Dir[File.expand_path("../spec/fixtures/*.json", __dir__)]
HEROKU = File.expand_path("../spec/fixtures/heroku.json", __dir__)
DATA = File.read(HEROKU)
RUNS = (ARGV[0] || 3).to_i

# Regression caps, calibrated per environment: the ratio looked
# machine-independent but is not — CI runners (2 vCPU, shared) inflate the
# Ruby-vs-C balance ~2x versus a local M-series machine (first real CI run:
# from_json 5901x, e2e 7853x, suite itself green). Caps catch real
# regressions (1.3x+ of the environment's own baseline) without flaking.
# Aspirational budgets are printed separately.
IN_CI = ["true", "1"].include?(ENV.fetch("CI", nil))
CAP_FROM_JSON_RATIO, CAP_E2E_RATIO =
  if IN_CI
    [7_500, 10_000]
  else
    [2_600, 5_000]
  end

def median(values)
  values.sort[values.length / 2]
end

def measure(runs, &)
  Array.new(runs) { Benchmark.realtime(&) }
end

Schema = Lutaml::Jsonschema::Schema

# Warmup
Schema.from_json(DATA)
JSON.parse(DATA)

parse_times = measure(RUNS) { JSON.parse(DATA) }
from_json_times = measure(RUNS) { Schema.from_json(DATA) }

tmp = Dir.mktmpdir
frontend_built = File.exist?(
  File.join(Lutaml::Jsonschema::Spa::VueInlinedStrategy::FRONTEND_DIST,
            "app.iife.js"),
)
generate = lambda do
  set = Lutaml::Jsonschema::SchemaSet.load_from_files(*FIXTURES)
  Lutaml::Jsonschema::Spa::Generator.new(set, tmp).generate
end
if frontend_built
  generate.call
  e2e_times = measure(RUNS) { generate.call }
else
  e2e_times = nil
end

parse_ms = median(parse_times) * 1000
from_json_ms = median(from_json_times) * 1000
e2e_ms = e2e_times && (median(e2e_times) * 1000)

from_json_ratio = from_json_ms / parse_ms
e2e_ratio = e2e_ms && (e2e_ms / parse_ms)

per_100kb = from_json_ms / (DATA.bytesize / 100_000.0)
html_bytes = if e2e_ms
               File.size(File.join(tmp, "index.html"))
             end

puts "heroku.json: #{DATA.bytesize} bytes, #{FIXTURES.length} fixtures, " \
     "runs=#{RUNS}"
puts format("JSON.parse (reference):   %<ms>10.3f ms", ms: parse_ms)
puts format("Schema.from_json:         %<ms>10.3f ms  " \
            "(%<per>0f ms/100KB, %<ref>0fx ref)",
            ms: from_json_ms, per: per_100kb, ref: from_json_ratio)
if e2e_ms
  puts format("e2e spa generate:         %<ms>10.3f ms  (%<ref>0fx ref)",
              ms: e2e_ms, ref: e2e_ratio)
  puts format("index.html:               %<bytes>10d bytes " \
              "(%<ratio>0.2fx input)",
              bytes: html_bytes, ratio: html_bytes.to_f / DATA.bytesize)
else
  puts "e2e spa generate:         skipped (frontend/dist not built)"
end
puts
puts "environment: #{IN_CI ? 'CI' : 'local'}"
puts "budgets (aspirational): from_json <= #{DATA.bytesize / 1000} ms " \
     "(100 ms/100KB), e2e <= 1 s/MB"
puts "regression caps:        from_json ratio <= #{CAP_FROM_JSON_RATIO}, " \
     "e2e ratio <= #{CAP_E2E_RATIO}"

failures = []
failures << "from_json ratio #{from_json_ratio.round} > #{CAP_FROM_JSON_RATIO}" \
  if from_json_ratio > CAP_FROM_JSON_RATIO
failures << "e2e ratio #{e2e_ratio.round} > #{CAP_E2E_RATIO}" \
  if e2e_ratio && e2e_ratio > CAP_E2E_RATIO

if failures.empty?
  puts "PERF OK"
else
  warn "PERF REGRESSION: #{failures.join('; ')}"
  exit 1
end
