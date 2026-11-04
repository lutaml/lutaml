# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "expressir/commands/smrl_xml_index"

RSpec.describe Expressir::Commands::SmrlXmlIndex do
  let(:dir) do
    d = Dir.mktmpdir("smrl-index-")
    File.write(File.join(d, "alpha.exp"), <<~EXP)
      SCHEMA alpha;
      ENTITY alpha_entity; END_ENTITY;
      END_SCHEMA;
    EXP
    FileUtils.mkdir_p(File.join(d, "nested"))
    File.write(File.join(d, "nested", "beta.exp"), <<~EXP)
      SCHEMA beta_schema;
      CONSTANT beta_const : INTEGER := 1; END_CONSTANT;
      END_SCHEMA;
    EXP
    d
  end

  after { FileUtils.remove_entry(dir) }

  it "writes the SMRL index for every schema under the directory to stdout" do
    expect do
      described_class.new({}).run(dir)
    end.to output(/<smrl>/).to_stdout
  end

  it "writes the index to the output file when given" do
    out = File.join(dir, "smrl.xml")
    described_class.new(output: out).run(dir)
    content = File.read(out)
    expect(content).to include("<smrl>")
    expect(content).to include("<schema>alpha<!--")
    expect(content).to include("<schema>beta_schema<!--")
  end

  it "raises when no schemas are found" do
    empty = File.join(dir, "empty")
    FileUtils.mkdir_p(empty)
    expect do
      described_class.new({}).run(empty)
    end.to raise_error(Thor::Error, /no schemas under/)
  end
end
