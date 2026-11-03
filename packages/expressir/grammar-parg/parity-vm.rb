# frozen_string_literal: true

# STEP 5 gate (issue #578): the rs VM (mode: :native) and the ruby
# atom evaluation (mode: :ruby) must produce identical trees from the
# edition-2 artifact. Slices normalize to their content for the
# comparison, matching parsanol's repetition-flatten-parity spec.
#
# Usage: ruby parity-vm.rb

require "bundler/setup"
require "expressir"
require "parsanol"
require "json"

artifact = Parsanol::PARG::Artifact.from_json(
  File.read(File.join(__dir__, "express-grammar.artifact.json")),
)

NORMALIZE = lambda do |value|
  case value
  when Hash then value.to_h { |key, item| [key, NORMALIZE.call(item)] }
  when Array then value.map { |item| NORMALIZE.call(item) }
  else value.to_s
  end
end

pass = 0
fail = 0
skipped = 0
failures = []

Dir.glob(File.expand_path("../spec/**/*.exp", __dir__)).each do |f|
  src = File.read(f)

  begin
    ruby_tree = artifact.parse("syntax", src, mode: :ruby)
  rescue StandardError
    skipped += 1
    next
  end

  begin
    native_tree = artifact.parse("syntax", src, mode: :native)
  rescue StandardError, NotImplementedError => e
    fail += 1
    failures << [f, "native lane: #{e.class}: #{e.message[0, 120]}"]
    next
  end

  if NORMALIZE.call(ruby_tree) == NORMALIZE.call(native_tree)
    pass += 1
  else
    fail += 1
    failures << [f, "trees diverge between native and ruby"]
  end
end

puts "vm parity: #{pass} agree, #{fail} diverge, #{skipped} skipped (ruby lane fails)"
failures.first(10).each { |f, why| puts "  VM GAP: #{File.basename(f)} — #{why}" }
exit(fail.zero? ? 0 : 1)
