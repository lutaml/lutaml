# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "stringio"
require "tmpdir"
require "fileutils"
require "yaml"

# TODO.compat/02: `expressir doctor` assesses a workspace — schemas
# parse, instance datasets load, mapping files bind — and can emit a
# starter schema manifest.
RSpec.describe Expressir::Commands::Doctor do
  let(:schema_exp) do
    <<~EXPRESS
      SCHEMA demo;
        ENTITY point;
          x : REAL;
        END_ENTITY;
      END_SCHEMA;
    EXPRESS
  end

  let(:workspace) do
    dir = Dir.mktmpdir("doctor")
    File.write(File.join(dir, "demo.exp"), schema_exp)
    File.write(File.join(dir, "demo.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('d','2026-10-23T00:00:00',(''),(''),'','','');
      FILE_SCHEMA(('DEMO'));
      ENDSEC;
      DATA;
      #1=POINT(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    dir
  end

  def run_doctor(options = {}, dir = workspace)
    out = StringIO.new
    original = $stdout
    $stdout = out
    described_class.new(options).run(dir)
    out.string
  ensure
    $stdout = original
  end

  after { FileUtils.rm_rf(workspace) }

  it "reports the workspace ready" do
    out = run_doctor
    expect(out).to include("ready schema #{File.join(workspace, 'demo.exp')}")
    expect(out).to include("ready instance #{File.join(workspace, 'demo.p21')}")
    expect(out).to include("ready: 2 file(s)")
  end

  it "emits a starter manifest listing the ready schemas" do
    manifest = File.join(workspace, "manifest.yml")
    out = run_doctor(emit_manifest: manifest)
    expect(out).to include("starter manifest written to #{manifest}")
    parsed = YAML.safe_load_file(manifest)
    expect(parsed["files"]).to eq([File.join(workspace, "demo.exp")])
  end

  it "flags an unreadable file instead of failing the run" do
    File.write(File.join(workspace, "broken.exp"), "SCHEMA broken;")
    out = run_doctor
    expect(out).to include("UNREADABLE schema")
    expect(out).to include("ready: 2 file(s)")
  end
end
