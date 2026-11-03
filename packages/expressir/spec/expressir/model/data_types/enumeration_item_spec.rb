require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::EnumerationItem do
  describe ".new" do
    subject(:enum_item) do
      described_class.new(
        id: id,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "RED" }
    let(:remarks) { ["Primary color", "First item in list"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1",
                                                       remarks: ["Detail 1"]),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2",
                                                       remarks: ["Detail 2"]),
      ]
    end

    it "creates an enumeration item" do
      expect(enum_item).to be_a described_class
      expect(enum_item.id).to eq "RED"
      expect(enum_item.remarks).to eq ["Primary color", "First item in list"]
      expect(enum_item.remark_items).to contain_exactly(
        have_attributes(id: "remark1", remarks: ["Detail 1"]),
        have_attributes(id: "remark2", remarks: ["Detail 2"]),
      )
    end
  end

  describe "#children" do
    subject(:enum_item) do
      described_class.new(
        id: "RED",
        remark_items: remark_items,
      )
    end

    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
      ]
    end

    it "returns remark items" do
      expect(enum_item.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "without remark items" do
      let(:remark_items) { nil }

      it "returns empty array" do
        expect(enum_item.children).to be_empty
      end
    end
  end

  describe "identifier handling" do
    context "with different id formats" do
      let(:lowercase_item) { described_class.new(id: "red") }
      let(:mixed_case_item) { described_class.new(id: "Red") }
      let(:numeric_item) { described_class.new(id: "COLOR_1") }
      let(:special_chars_item) { described_class.new(id: "RED_BLUE_GREEN") }

      it "handles lowercase identifiers" do
        expect(lowercase_item.id).to eq "red"
      end

      it "handles mixed case identifiers" do
        expect(mixed_case_item.id).to eq "Red"
      end

      it "handles identifiers with numbers" do
        expect(numeric_item.id).to eq "COLOR_1"
      end

      it "handles identifiers with underscores" do
        expect(special_chars_item.id).to eq "RED_BLUE_GREEN"
      end
    end

    context "with edge cases" do
      let(:empty_id_item) { described_class.new(id: "") }
      let(:single_char_item) { described_class.new(id: "R") }
      let(:very_long_id_item) { described_class.new(id: "A" * 100) }

      it "handles empty identifiers" do
        expect(empty_id_item.id).to eq ""
      end

      it "handles single character identifiers" do
        expect(single_char_item.id).to eq "R"
      end

      it "handles very long identifiers" do
        expect(very_long_id_item.id.length).to eq 100
      end
    end
  end

  describe "remark handling" do
    context "with different remark formats" do
      let(:multiline_remarks) do
        described_class.new(
          id: "RED",
          remarks: [
            "First line\nSecond line",
            "Third line\nFourth line",
          ],
        )
      end

      let(:special_chars_remarks) do
        described_class.new(
          id: "RED",
          remarks: [
            "Contains special chars: !@#$%^&*()",
            "Unicode: αβγδε",
          ],
        )
      end

      let(:empty_remarks) do
        described_class.new(
          id: "RED",
          remarks: ["", "  ", "\n"],
        )
      end

      it "handles multiline remarks" do
        expect(multiline_remarks.remarks).to contain_exactly(
          "First line\nSecond line",
          "Third line\nFourth line",
        )
      end

      it "handles special characters in remarks" do
        expect(special_chars_remarks.remarks).to contain_exactly(
          "Contains special chars: !@#$%^&*()",
          "Unicode: αβγδε",
        )
      end

      it "handles empty remarks" do
        expect(empty_remarks.remarks).to contain_exactly("", "  ", "\n")
      end
    end
  end

  describe "parent-child relationships" do
    let(:parent_enum) do
      Expressir::Model::DataTypes::Enumeration.new(
        id: "COLOR",
        items: [
          described_class.new(id: "RED"),
          described_class.new(id: "GREEN"),
          described_class.new(id: "BLUE"),
        ],
      )
    end

    it "establishes correct parent relationship" do
      expect(parent_enum.items.first.parent).to eq parent_enum
      expect(parent_enum.items.last.parent).to eq parent_enum
    end

    it "maintains correct ordering" do
      expect(parent_enum.items.map(&:id)).to eq ["RED", "GREEN", "BLUE"]
    end
  end
end
