# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"

RSpec.describe Expressir::Commands::Receipt do
  let(:workspace) do
    dir = Dir.mktmpdir("receipt")
    File.write(File.join(dir, "schema.exp"), <<~EXP)
      SCHEMA sensor;
      ENTITY reading;
        reading_value : REAL;
      END_ENTITY;
      END_SCHEMA;
    EXP
    File.write(File.join(dir, "population.yml"), <<~YAML)
      schema: schema.exp
      release: r1
      files:
        - a.p21
      short_names:
        RDG: reading
    YAML
    File.write(File.join(dir, "a.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('a.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('sensor'));
      ENDSEC;
      DATA;
      #1=RDG(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    arm_dir = File.join(dir, "mapping")
    FileUtils.mkdir_p(arm_dir)
    File.write(File.join(arm_dir, "arm.exp"), <<~EXP)
      SCHEMA sensor_arm;
      USE FROM sensor;
      ENTITY reading_arm;
        reading : reading;
      END_ENTITY;
      END_SCHEMA;
    EXP
    File.write(File.join(arm_dir, "mapping.yaml"), <<~YAML)
      mapping:
        - arm: <<express:sensor_arm.reading_arm>>
          mim: <<express:sensor.reading>>
    YAML
    File.write(File.join(dir, "workspace.yml"), <<~YAML)
      schema_files:
        - schema.exp
      datasets:
        - population.yml
      mappings:
        - mapping/mapping.yaml
    YAML
    dir
  end

  after do
    FileUtils.rm_rf(workspace)
  end

  def run_receipt(dir, output)
    described_class.new({ output: output }).run(File.join(dir, "workspace.yml"))
  end

  it "one manifest drives one receipt covering all three validators" do
    receipt_path = File.join(workspace, "receipt.json")
    run_receipt(workspace, receipt_path)
    receipt = JSON.parse(File.read(receipt_path))

    expect(receipt["artifact"]).to eq("expressir-receipt")
    expect(receipt["verdicts"]["schema"]["valid"]).to be(true)
    expect(receipt["verdicts"]["datasets"].first["release"]).to eq("r1")
    expect(receipt["verdicts"]["datasets"].first["files"].first["digest"])
      .to match(/\A[0-9a-f]{64}\z/)
    expect(receipt["verdicts"]["mappings"].first["valid"]).to be(true)
    expect(receipt["summary"]["valid"]).to be(true)
    expect(receipt["inputs"]["schema_files"]).to have_key("schema.exp")
  end

  it "reruns byte-identically" do
    first = File.join(workspace, "first.json")
    second = File.join(workspace, "second.json")
    run_receipt(workspace, first)
    run_receipt(workspace, second)
    expect(File.read(first)).to eq(File.read(second))
  end

  it "emits canonical bytes: sorted keys, no insignificant whitespace" do
    receipt_path = File.join(workspace, "receipt.json")
    run_receipt(workspace, receipt_path)
    bytes = File.read(receipt_path)
    reparsed = JSON.parse(bytes)
    expect(bytes).to eq(JSON.generate(reparsed))

    top_keys = reparsed.keys
    expect(top_keys).to eq(top_keys.sort)
  end

  it "reports and exits nonzero when a validator finds errors" do
    File.write(File.join(workspace, "b.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('b.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('sensor'));
      ENDSEC;
      DATA;
      #2=UNKNOWN_ENTITY(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    File.write(File.join(workspace, "population.yml"), <<~YAML)
      schema: schema.exp
      release: r1
      files:
        - a.p21
        - b.p21
      short_names:
        RDG: reading
    YAML

    receipt_path = File.join(workspace, "receipt.json")
    expect do
      run_receipt(workspace, receipt_path)
    end.to raise_error(Thor::Error, /error/)
    receipt = JSON.parse(File.read(receipt_path))

    expect(receipt["summary"]["valid"]).to be(false)
    expect(receipt["summary"]["errors"]).to be_positive
  end
end
