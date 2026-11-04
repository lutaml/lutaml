# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "expressir"

RSpec.describe Expressir::P21::Receipt do
  let(:schema) do
    Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
      SCHEMA demo;
      ENTITY point; x : REAL; END_ENTITY;
      END_SCHEMA;
    EXP
  end

  let(:manifest) do
    Expressir::P21::DatasetManifest.new(
      schema: "demo.exp", release: "r1",
      files: [File.join(dir, "a.p21")]
    )
  end

  let(:dir) do
    dir = Dir.mktmpdir("receipt")
    File.write(File.join(dir, "a.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('a.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('demo'));
      ENDSEC;
      DATA;
      #1=POINT(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    dir
  end

  after do
    FileUtils.rm_rf(dir)
  end

  def build_receipt
    population = Expressir::P21::Parser.parse(
      File.read(File.join(dir, "a.p21")),
    )
    notes = Expressir::P21::Validator.validate(population, schema)
    described_class.build(manifest, File.join(dir, "a.p21") => notes)
  end

  it "produces a byte-identical receipt for the same run" do
    # Two independent validate+build runs over the same file must
    # serialize to exactly the same bytes.
    first = build_receipt
    second = described_class.build(
      manifest,
      File.join(dir, "a.p21") => Expressir::P21::Validator.validate(
        Expressir::P21::Parser.parse(File.read(File.join(dir, "a.p21"))),
        schema,
      ),
    )
    expect(second).to eq(first)
  end

  it "records the release, per-file digests and summary" do
    report = JSON.parse(build_receipt)
    expect(report["release"]).to eq("r1")
    expect(report["validator"]).to eq("expressir #{Expressir::VERSION}")
    expect(report["files"].first["digest"]).to be_a(String)
    expect(report["files"].first["notes"]).to be_empty
    expect(report["summary"]).to eq("files" => 1, "errors" => 0,
                                    "warnings" => 0)
  end

  it "records findings with ids and severities" do
    population = Expressir::P21::Parser.parse(
      File.read(File.join(dir, "a.p21")).sub("#1=POINT(1.0);", "#1=POINT('x');"),
    )
    notes = Expressir::P21::Validator.validate(population, schema)
    report = JSON.parse(
      described_class.build(manifest, File.join(dir, "a.p21") => notes),
    )
    expect(report["summary"]["errors"]).to eq(1)
    expect(report["files"].first["notes"].first["id"])
      .to eq("check_p21_value_domain")
  end
end
