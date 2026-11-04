# frozen_string_literal: true

require "spec_helper"

# Corpus-scale pretty round-trip gate (parity-ee stage 08).
# parse → Formatter → re-parse; structural fingerprint must match.
EXAMPLES = Dir[File.expand_path("../../fixtures/examples/*.exp", __dir__)].freeze

RSpec.describe Expressir::Express::PrettyGate do
  it "has example fixtures to gate" do
    expect(EXAMPLES).not_to be_empty
  end

  EXAMPLES.each do |path|
    it "round-trips #{File.basename(path)}" do
      result = described_class.check_file(path)
      if result.error
        raise "parse/format failed for #{path}: #{result.error.class}: #{result.error.message}"
      end

      expect(result.after).to eq(result.before), lambda {
        diff_keys = result.before.zip(result.after).flat_map do |b, a|
          (b.keys | a.keys).reject { |k| b[k] == a[k] }
        end.uniq
        "fingerprint drift in #{diff_keys.inspect} for #{path}"
      }
    end
  end

  it "detects drift when a declaration is dropped" do
    src = <<~EXP
      SCHEMA s;
      TYPE t = STRING; END_TYPE;
      ENTITY e;
        x : t;
      END_ENTITY;
      END_SCHEMA;
    EXP
    original = Expressir::Express::Parser.from_exp(src, skip_references: true)
    before = described_class.fingerprint(original.schemas.first)
    original.schemas.first.types = []
    after = described_class.fingerprint(original.schemas.first)
    expect(after).not_to eq(before)
  end
end
