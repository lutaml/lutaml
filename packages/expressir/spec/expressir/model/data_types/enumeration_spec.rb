require "spec_helper"

RSpec.describe Expressir::Model::DataTypes::Enumeration do
  describe ".new" do
    subject(:enumeration) do
      described_class.new(
        extensible: extensible,
        based_on: based_on,
        items: items,
      )
    end

    let(:extensible) { true }
    let(:based_on) do
      Expressir::Model::References::SimpleReference.new(
        id: "base_enum",
      )
    end
    let(:items) do
      [
        Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
        Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
      ]
    end

    it "creates an enumeration type" do
      expect(enumeration).to be_a described_class
      expect(enumeration.extensible).to be true
      expect(enumeration.based_on.id).to eq "base_enum"
      expect(enumeration.items.map(&:id)).to eq ["ITEM1", "ITEM2"]
    end
  end

  describe "extensibility behavior" do
    context "with different extensibility settings" do
      let(:extensible_enum) do
        described_class.new(
          extensible: true,
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
          ],
        )
      end

      let(:non_extensible_enum) do
        described_class.new(
          extensible: false,
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
          ],
        )
      end

      let(:default_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
          ],
        )
      end

      it "handles extensible enumerations" do
        expect(extensible_enum.extensible).to be true
      end

      it "handles non-extensible enumerations" do
        expect(non_extensible_enum.extensible).to be false
      end

      it "handles default extensibility" do
        expect(default_enum.extensible).to be_nil
      end
    end
  end

  describe "inheritance behavior" do
    context "with different base types" do
      let(:base_enum) do
        described_class.new(
          id: "BASE",
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
          ],
        )
      end

      let(:derived_enum) do
        described_class.new(
          id: "DERIVED",
          based_on: Expressir::Model::References::SimpleReference.new(id: "BASE"),
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM3"),
          ],
        )
      end

      let(:empty_derived_enum) do
        described_class.new(
          id: "EMPTY_DERIVED",
          based_on: Expressir::Model::References::SimpleReference.new(id: "BASE"),
        )
      end

      it "handles base enumeration" do
        expect(base_enum.items.map(&:id)).to eq ["ITEM1", "ITEM2"]
        expect(base_enum.based_on).to be_nil
      end

      it "handles derived enumeration with additional items" do
        expect(derived_enum.based_on.id).to eq "BASE"
        expect(derived_enum.items.map(&:id)).to eq ["ITEM3"]
      end

      it "handles derived enumeration without additional items" do
        expect(empty_derived_enum.based_on.id).to eq "BASE"
        expect(empty_derived_enum.items).to eq([])
      end
    end
  end

  describe "item management" do
    context "with different item configurations" do
      let(:empty_enum) { described_class.new }

      let(:single_item_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
          ],
        )
      end

      let(:duplicate_items_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
          ],
        )
      end

      let(:complex_items_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(
              id: "ITEM1",
              remarks: ["First item"],
            ),
            Expressir::Model::DataTypes::EnumerationItem.new(
              id: "ITEM2",
              remarks: ["Second item"],
            ),
          ],
        )
      end

      it "handles empty enumeration" do
        expect(empty_enum.items).to eq([])
      end

      it "handles single item enumeration" do
        expect(single_item_enum.items.length).to eq 1
        expect(single_item_enum.items.first.id).to eq "ITEM1"
      end

      it "handles duplicate items" do
        expect(duplicate_items_enum.items.map(&:id)).to eq ["ITEM1", "ITEM1"]
      end

      it "handles items with remarks" do
        expect(complex_items_enum.items.first.remarks).to eq ["First item"]
        expect(complex_items_enum.items.last.remarks).to eq ["Second item"]
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:circular_reference) do
        enum1 = described_class.new(id: "ENUM1")
        described_class.new(
          id: "ENUM2",
          based_on: Expressir::Model::References::SimpleReference.new(id: "ENUM1"),
        )
        enum1.based_on = Expressir::Model::References::SimpleReference.new(id: "ENUM2")
        enum1
      end

      let(:deeply_nested_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(
              id: "ITEM1",
              remark_items: [
                Expressir::Model::Declarations::RemarkItem.new(
                  id: "remark1",
                  remarks: ["Nested remark"],
                ),
              ],
            ),
          ],
        )
      end

      let(:mixed_case_enum) do
        described_class.new(
          items: [
            Expressir::Model::DataTypes::EnumerationItem.new(id: "item1"),
            Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
            Expressir::Model::DataTypes::EnumerationItem.new(id: "Item3"),
          ],
        )
      end

      it "handles circular references" do
        expect(circular_reference.based_on.id).to eq "ENUM2"
      end

      it "handles deeply nested structures" do
        expect(deeply_nested_enum.items.first.remark_items.first.remarks).to eq ["Nested remark"]
      end

      it "preserves item case sensitivity" do
        expect(mixed_case_enum.items.map(&:id)).to eq ["item1", "ITEM2",
                                                       "Item3"]
      end
    end
  end
end
