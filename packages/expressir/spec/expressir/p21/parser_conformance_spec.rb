# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.sota/03 part 1 + TODO.instance/03 part 1: the ISO 10303-21
# conformance corpus extracted from the standard's detached source
# (conformance/*.p21). The full ladder — named DATA sections
# (annex E), ANCHOR/REFERENCE sections (annex I), EXPRESS-constant
# references (annex J) — parses clean; genuinely malformed input
# fails loudly rather than being silently accepted.
#
# Two extraction errata in the published detachment are corrected in
# the fixtures, each unambiguous from the grammar: annex E's
# `'1300 Elmwood Avenue);` is missing its closing quote, and annex J
# drops one `)` after GLOBAL_UNIT_ASSIGNED_CONTEXT plus carries an
# Asciidoc `....` listing delimiter (document.err records the first).
RSpec.describe Expressir::P21::Parser do
  def fixture(name)
    File.read(Expressir.root_path.join("spec/fixtures/p21/conformance", name))
  end

  it "parses the Annex H complete exchange structure" do
    population = described_class.parse(fixture("annex-h-0.p21"))
    expect(population.instances.size).to eq(13)
  end

  describe "Annex E: named DATA sections" do
    it "parses both sections with their schema contexts" do
      population = described_class.parse(fixture("annex-e-0.p21"))
      expect(population.instances.size).to eq(5)
      expect(population.sections.map(&:name)).to eq(%w[ONE TWO])
      expect(population.sections.map(&:contexts))
        .to eq([%w[BASE], %w[EXTENSION]])
    end

    it "binds each section's instances" do
      population = described_class.parse(fixture("annex-e-1.p21"))
      expect(population.sections.map(&:instance_ids))
        .to eq([%w[#1 #2 #3], %w[#4 #5]])
    end
  end

  describe "Annex I: anchors and references" do
    it "parses anchors, references and the SCHEMA_POPULATION header" do
      population = described_class.parse(fixture("annex-i-0.p21"))
      expect(population.anchors).to eq(
        "POINT_1" => "#1", "POINT_2" => "#2", "POINT_3" => "#3",
        "POINT_4" => "#4", "POINT_5" => "#5", "POINT_6" => :unset
      )
      expect(population.references)
        .to eq("#11" => "<ftp://ftp.acme.net/second_file.stp#vertex_1>")
      expect(population.header["SCHEMA_POPULATION"]).not_to be_nil
    end

    it "parses the subsidiary annex I file" do
      population = described_class.parse(fixture("annex-i-1.p21"))
      expect(population.anchors).to eq("vertex_1" => "#11")
      expect(population.references)
        .to eq("#1" => "<http://www.giant.com/first_file.stp#POINT_1>")
    end
  end

  describe "Annex J: EXPRESS-constant references" do
    it "parses the constant-referencing complex instance" do
      population = described_class.parse(fixture("annex-j-0.p21"))
      expect(population.instances.size).to eq(1)
      record = population.instances.values.first
      expect(record).to be_a(Expressir::P21::ComplexRecord)
      units = record.records[1]
      expect(units.params.first)
        .to eq(["#IMPERIAL_LENGTH_INCH", "#PLANE_ANGLE_RADIAN",
                "#SOLID_ANGLE_STERADIAN"])
    end
  end

  describe "malformed inputs" do
    it "rejects a truncated exchange structure" do
      expect { described_class.parse("ISO-10303-21;\nHEADER;\n") }
        .to raise_error(StandardError)
    end

    it "rejects a missing END marker" do
      source = fixture("annex-h-0.p21").sub("END-ISO-10303-21;", "")
      expect { described_class.parse(source) }
        .to raise_error(StandardError)
    end

    it "rejects garbage in the data section" do
      source = fixture("annex-h-0.p21")
        .sub("#24=ED_LOOP((#21,#22,#23));", "NOT A RECORD")
      expect { described_class.parse(source) }
        .to raise_error(StandardError)
    end
  end
end
