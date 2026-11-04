# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "tmpdir"
require "json"

RSpec.describe Expressir::Commands::Population do
  let(:dataset_dir) do
    dir = Dir.mktmpdir("population")
    File.write(File.join(dir, "schema.exp"), <<~EXP)
      SCHEMA demo;
      ENTITY point; x : REAL; END_ENTITY;
      END_SCHEMA;
    EXP
    File.write(File.join(dir, "a.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('a.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('demo'));
      ENDSEC;
      DATA;
      #1=CPT(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    File.write(File.join(dir, "b.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('b.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('demo'));
      ENDSEC;
      DATA;
      #2=CPT(2.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    File.write(File.join(dir, "manifest.yml"), <<~YAML)
      schema: schema.exp
      release: r1
      files:
        - a.p21
      short_names:
        CPT: point
    YAML
    dir
  end

  after do
    FileUtils.rm_rf(dataset_dir)
  end

  it "validates a manifest dataset and writes a deterministic receipt" do
    receipt_a = File.join(dataset_dir, "receipt-a.json")
    receipt_b = File.join(dataset_dir, "receipt-b.json")
    described_class.start(
      ["validate", File.join(dataset_dir, "manifest.yml"), "-o", receipt_a],
    )
    described_class.start(
      ["validate", File.join(dataset_dir, "manifest.yml"), "-o", receipt_b],
    )
    expect(File.exist?(receipt_a)).to be(true)
    expect(File.read(receipt_a)).to eq(File.read(receipt_b))
    report = JSON.parse(File.read(receipt_a))
    expect(report["summary"]).to eq("files" => 1, "errors" => 0,
                                    "warnings" => 0)
  end

  it "fails the run when the dataset has error findings" do
    File.write(File.join(dataset_dir, "a.p21"),
               File.read(File.join(dataset_dir, "a.p21"))
                    .sub("#1=CPT(1.0);", "#1=CPT('x');"))
    raised = nil
    begin
      described_class.start(
        ["validate", File.join(dataset_dir, "manifest.yml")],
      )
    rescue SystemExit => e
      raised = e
    end
    expect(raised).not_to be_nil
    expect(raised.status).to eq(1)
  end

  it "diffs two populations by instance" do
    expect do
      described_class.start(
        ["diff", File.join(dataset_dir, "a.p21"),
         File.join(dataset_dir, "b.p21")],
      )
    end.to output(a_string_including("added:   #2", "removed: #1"))
      .to_stdout
  end
end
