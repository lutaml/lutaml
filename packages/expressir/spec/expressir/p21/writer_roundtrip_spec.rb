# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.instance/03 part 4 (round trips): the P21 writer re-emits a
# population deterministically with value identity, and the JSON
# interchange is value-identical in both directions.
RSpec.describe Expressir::P21::Writer do
  let(:population) do
    Expressir::P21::Parser.parse(fixture("annex-h-0.p21"))
  end

  def fixture(name)
    File.read(Expressir.root_path.join("spec/fixtures/p21/conformance", name))
  end

  it "re-emits Annex H with value identity" do
    text = described_class.emit(population)
    reparsed = Expressir::P21::Parser.parse(text)
    expect(reparsed.instances).to eq(population.instances)
  end

  it "serializes deterministically" do
    reparsed = Expressir::P21::Parser.parse(described_class.emit(population))
    expect(described_class.emit(reparsed))
      .to eq(described_class.emit(population))
  end

  it "re-emits anchors, references and named sections" do
    annex_i = Expressir::P21::Parser.parse(fixture("annex-i-0.p21"))
    text = described_class.emit(annex_i)
    reparsed = Expressir::P21::Parser.parse(text)
    expect(reparsed.anchors).to eq(annex_i.anchors)
    expect(reparsed.references).to eq(annex_i.references)
    expect(reparsed.instances).to eq(annex_i.instances)
  end

  it "re-emits named DATA sections with contexts" do
    annex_e = Expressir::P21::Parser.parse(fixture("annex-e-0.p21"))
    text = described_class.emit(annex_e)
    expect(text).to include("DATA ('ONE', ('BASE'));")
    reparsed = Expressir::P21::Parser.parse(text)
    expect(reparsed.instances).to eq(annex_e.instances)
    expect(reparsed.sections.map(&:name)).to eq(%w[ONE TWO])
  end
end
