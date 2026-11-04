# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::RemarkFormat do
  it "defines TAIL as 'tail'" do
    expect(described_class::TAIL).to eq("tail")
  end

  it "defines EMBEDDED as 'embedded'" do
    expect(described_class::EMBEDDED).to eq("embedded")
  end

  it "is the single source of truth referenced by RemarkInfo" do
    info = Expressir::Model::RemarkInfo.new(text: "x", format: described_class::TAIL)
    expect(info).to be_tail
    expect(info).not_to be_embedded
  end

  it "is referenced by the scanner" do
    remarks = Expressir::Express::RemarkScanner.new("-- hi\n").scan
    expect(remarks.first.format).to eq(described_class::TAIL)
  end
end
