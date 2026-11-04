# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "open3"

# TODO.eengine/07 oracle tier: expressir SchemaCompare vs eeng
# --compare. Needs the eengine binary and a stepmod checkout; skips
# otherwise (same gating pattern as NATIVE_AVAILABLE).
RSpec.describe Expressir::Express::SchemaCompare do
  let(:eengine) do
    Pathname.new(ENV.fetch("EENGINE_BIN", "#{Dir.home}/bin/eengine"))
  end
  let(:stepmod) do
    Pathname.new(ENV.fetch("STEPMOD_DIR", "#{Dir.home}/src/mn/iso-10303-stepmod"))
  end
  let(:deltas) do
    described_class.compare(parse_fixture("reference.exp"), parse_fixture("trial.exp"))
  end

  before { skip "eengine oracle or stepmod checkout not present" unless eengine.executable? && stepmod.directory? }

  def parse_fixture(name)
    Expressir::Express::Parser.from_exp(
      File.read(Expressir.root_path.join("spec/fixtures/compare", name)),
    ).schemas.first
  end

  def oracle_output
    @oracle_output ||= Open3.capture2e(
      eengine.to_s, "--compare", "-MODE", "RESOURCE", "-STEPMOD", stepmod.to_s,
      "-TRIAL_SCHEMA",
      Expressir.root_path.join("spec/fixtures/compare/trial.exp").to_s,
      "-REFERENCE_SCHEMA",
      Expressir.root_path.join("spec/fixtures/compare/reference.exp").to_s
    ).first
  end

  def oracle_names(regex)
    oracle_output.scan(regex).flatten.map(&:downcase)
  end

  def expressir_paths(delta_op, depth)
    deltas.select { |delta| delta.op == delta_op && delta.path.split(".").size == depth }
      .map { |delta| delta.path.split(".").last }
  end

  it "agrees on added entities" do
    expect(expressir_paths(:added, 2)).to eq(oracle_names(/Add ENTITY '(\w+)'/))
  end

  it "agrees on removed entities" do
    expect(expressir_paths(:removed, 2)).to eq(oracle_names(/Remove ENTITY '(\w+)'/))
  end

  it "agrees on removed attributes" do
    expect(expressir_paths(:removed, 3)).to eq(oracle_names(/Remove Attribute '(\w+)'/))
  end

  it "detects the same type-level change" do
    expect(deltas.map(&:path)).to include("cmp.status")
    expect(oracle_names(/Add ENUMERATION value '(\w+)'/)).to eq(%w[ugly])
  end
end
