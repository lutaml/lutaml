# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "tmpdir"
require "fileutils"

# TODO.compat/01: `expressir compare` emits the schema.changes
# interchange report, and the existing changes importer reads it back
# — the round trip proves the two-way street.
OLD_EXPRESS = <<~EXPRESS
  SCHEMA demo;
    ENTITY a;
      x : INTEGER;
    END_ENTITY;
  END_SCHEMA;
EXPRESS

NEW_EXPRESS = <<~EXPRESS
  SCHEMA demo;
    ENTITY a;
      x : INTEGER;
      y : STRING;
    END_ENTITY;
    ENTITY b;
      code : INTEGER;
    END_ENTITY;
  END_SCHEMA;
EXPRESS

RSpec.describe Expressir::Commands::Compare do
  def run_compare(dir)
    base = File.join(dir, "base.exp")
    revised = File.join(dir, "revised.exp")
    File.write(base, OLD_EXPRESS)
    File.write(revised, NEW_EXPRESS)
    report = File.join(dir, "report.xml")
    described_class.new({ output: report }).run(base, revised)
    File.read(report)
  end

  let(:report_xml) do
    Dir.mktmpdir do |dir|
      run_compare(dir)
    end
  end

  it "emits the schema.changes interchange shape" do
    expect(report_xml).to include("<schema.changes>")
    expect(report_xml).to include("<schema.additions>")
    # the classif attribute rides the classification (TODO.compat/06)
    expect(report_xml)
      .to include('<modified.object type="ENTITY" name="b" classif="additive">')
    expect(report_xml).to include("<schema.modifications>")
  end

  it "round trips through the changes importer" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "report.xml"), report_xml)
      result = Expressir::Commands::ChangesImportEengine.call(
        File.join(dir, "report.xml"), nil, "demo", 1
      )
      version = result.versions[0]
      names = version.additions.map(&:name)
      expect(names).to include("b")
      modifications = version.modifications.map(&:name)
      expect(modifications).to include("demo.a.y")
    end
  end

  it "emits deterministically" do
    first = nil
    second = nil
    Dir.mktmpdir do |dir|
      first = run_compare(dir)
    end
    Dir.mktmpdir do |dir|
      second = run_compare(dir)
    end
    expect(second).to eq(first)
  end
end
