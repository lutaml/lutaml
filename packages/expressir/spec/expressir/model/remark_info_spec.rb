require "spec_helper"

RSpec.describe Expressir::Model::RemarkInfo do
  describe "placement" do
    it "round-trips a leading remark through YAML" do
      info = described_class.new(
        text: "note", format: Expressir::Model::RemarkFormat::TAIL,
        placement: Expressir::Model::RemarkPlacement::LEADING
      )

      expect(described_class.from_yaml(info.to_yaml).leading?).to be true
    end

    it "round-trips through XML" do
      info = described_class.new(
        text: "note", format: Expressir::Model::RemarkFormat::TAIL,
        placement: Expressir::Model::RemarkPlacement::LEADING
      )

      expect(described_class.from_xml(info.to_xml).leading?).to be true
    end

    it "omits placement when unset, keeping payloads lean" do
      yaml = described_class.new(
        text: "note", format: Expressir::Model::RemarkFormat::TAIL,
      ).to_yaml

      expect(yaml).not_to include("placement")
    end

    # Caches written before placement existed must keep their historical
    # emission, so the predicate has to answer false for nil.
    it "treats a legacy payload as unplaced" do
      legacy = described_class.from_yaml("---\ntext: old\nformat: tail\n")

      expect(legacy).to have_attributes(placement: nil, leading?: false)
    end
  end
end
