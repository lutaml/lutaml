# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "expressir"

RSpec.describe Expressir::P21::DatasetManifest do
  subject(:manifest) do
    described_class.from_file(File.join(manifest_dir, "manifest.yml"))
  end

  let(:manifest_dir) do
    dir = Dir.mktmpdir("manifest")
    File.write(File.join(dir, "schema.exp"), <<~EXP)
      SCHEMA demo;
      ENTITY point; x : REAL; END_ENTITY;
      END_SCHEMA;
    EXP
    File.write(File.join(dir, "points.p21"), <<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('p.stp','2026-01-01T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('demo'));
      ENDSEC;
      DATA;
      #1=CPT(1.0);
      ENDSEC;
      END-ISO-10303-21;
    P21
    File.write(File.join(dir, "manifest.yml"), <<~YAML)
      schema: schema.exp
      release: r1
      files:
        - points.p21
      short_names:
        CPT: point
    YAML
    dir
  end

  after do
    FileUtils.rm_rf(manifest_dir)
  end

  it "loads the binding and normalizes short-name keys" do
    expect(manifest.release).to eq("r1")
    expect(manifest.file_paths).to eq([File.join(manifest_dir, "points.p21")])
    expect(manifest.schema_path).to eq(File.join(manifest_dir, "schema.exp"))
    expect(manifest.short_name_map).to eq("cpt" => "point")
  end

  it "rejects the schema-manifest entry shape with a clear error" do
    File.write(File.join(manifest_dir, "structured.yml"),
               "schema: schema.exp\nrelease: r1\nfiles:\n  - path: points.p21\n")
    expect do
      described_class.from_file(File.join(manifest_dir, "structured.yml"))
    end.to raise_error(
      Expressir::ManifestValidationError,
      /entry 0 is not a plain file path/,
    )
  end
end
