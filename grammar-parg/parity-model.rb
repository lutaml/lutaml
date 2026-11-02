# frozen_string_literal: true

# STEP 3 gate (issue #578): the builder must produce identical models
# from the lane the artifact REPLACES (the DSL-wrapped fallback) and
# the artifact lane. Fixtures where the DSL lane itself fails count as
# out of scope: the runtime flip falls back to the DSL lane there, so
# behavior is identical either way.
#
# Usage: ruby parity-model.rb

require "bundler/setup"
require "expressir"
require "parsanol"
require "json"

artifact_path = File.join(__dir__, "express-grammar.artifact.json")
artifact = Parsanol::PARG::Artifact.from_json(File.read(artifact_path))

pass = 0
fail = 0
skipped = 0
failures = []

fixtures = Dir.glob(File.expand_path("../spec/**/*.exp", __dir__))

fixtures.each do |f|
  src = File.read(f)

  dsl_ast = nil
  begin
    dsl_ast = Expressir::Express::Grammar::Parser.cached_parser.parse(src)
    dsl_model = Expressir::Express::Builder.build_with_remarks(dsl_ast, source: src, include_source: false)
  rescue StandardError, NotImplementedError
    dsl_ast = nil
  end

  begin
    art_ast = artifact.parse("syntax", src, mode: :ruby)
    art_model = Expressir::Express::Builder.build_with_remarks(art_ast, source: src, include_source: false)
  rescue StandardError, NotImplementedError => e
    if dsl_ast.nil?
      skipped += 1
    else
      fail += 1
      failures << [f, "artifact lane: #{e.class}: #{e.message[0, 120]}"]
    end
    next
  end

  if dsl_ast.nil?
    skipped += 1
    next
  end

  dsl_h = dsl_model.to_hash
  art_h = art_model.to_hash
  if dsl_h == art_h
    pass += 1
  else
    fail += 1
    diff = dsl_h.keys == art_h.keys ? "content" : "top keys #{dsl_h.keys.inspect} vs #{art_h.keys.inspect}"
    failures << [f, "model diverge (#{diff})"]
  end
end

puts "model parity: #{pass} agree, #{fail} diverge, #{skipped} out-of-scope (#{fixtures.size} fixtures)"
failures.first(15).each { |f, why| puts "  MODEL GAP: #{File.basename(f)} — #{why}" }
exit(fail.zero? ? 0 : 1)
