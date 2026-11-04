# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "tempfile"

RSpec.describe Expressir::Conformance::Trend do
  it "measures parse, diagnostic and idempotence rates" do
    valid = Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp")
    broken = Tempfile.new(["broken", ".exp"])
    broken.write("SCHEMA broken;\nENTITY thing\nEND_SCHEMA;\n")
    broken.close
    begin
      report = described_class.measure([valid.to_s, broken.path])
      expect(report["files"]).to eq(2)
      expect(report["parsed"]).to eq(1)
      expect(report["parse_failed"]).to eq(1)
      expect(report["idempotent"]).to eq(1)
      expect(report["not_idempotent"]).to eq(0)
      expect(report["parse_rate"]).to eq(0.5)
      expect(report["idempotence_rate"]).to eq(1.0)
      expect(report["note_ids"]).to be_a(Hash)
    ensure
      broken.unlink
    end
  end

  it "writes the report as JSON" do
    valid = Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp")
    output = Tempfile.new(["trend", ".json"])
    output.close
    begin
      described_class.run([valid.to_s], output: output.path)
      report = JSON.parse(File.read(output.path))
      expect(report).to include("files" => 1, "parsed" => 1,
                                "idempotence_rate" => 1.0)
      expect(report["note_ids"]).to be_a(Hash)
    ensure
      output.unlink
    end
  end
end
