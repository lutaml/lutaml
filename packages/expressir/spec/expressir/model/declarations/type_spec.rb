require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Type do
  describe ".new" do
    subject(:type) do
      described_class.new(
        id: id,
        underlying_type: underlying_type,
        where_rules: where_rules,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_type" }
    let(:underlying_type) { Expressir::Model::DataTypes::String.new }
    let(:where_rules) do
      [
        Expressir::Model::Declarations::WhereRule.new(
          id: "WR1",
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        ),
      ]
    end
    let(:remarks) { ["Test type remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a type" do
      expect(type).to be_a described_class
      expect(type.id).to eq "test_type"
      expect(type.underlying_type).to be_a Expressir::Model::DataTypes::String
      expect(type.where_rules.first.id).to eq "WR1"
      expect(type.remarks).to eq ["Test type remark"]
      expect(type.remark_items.first.id).to eq "remark1"
    end
  end

  describe "underlying type handling" do
    context "with different underlying types" do
      let(:simple_type) do
        described_class.new(
          id: "simple_type",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:array_type) do
        described_class.new(
          id: "array_type",
          underlying_type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
            bound1: Expressir::Model::Literals::Integer.new(value: "1"),
            bound2: Expressir::Model::Literals::Integer.new(value: "10"),
          ),
        )
      end

      let(:enumeration_type) do
        described_class.new(
          id: "enum_type",
          underlying_type: Expressir::Model::DataTypes::Enumeration.new(
            items: [
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
            ],
          ),
        )
      end

      let(:select_type) do
        described_class.new(
          id: "select_type",
          underlying_type: Expressir::Model::DataTypes::Select.new(
            items: [
              Expressir::Model::References::SimpleReference.new(id: "type1"),
              Expressir::Model::References::SimpleReference.new(id: "type2"),
            ],
          ),
        )
      end

      it "handles simple types" do
        expect(simple_type.underlying_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles array types" do
        expect(array_type.underlying_type).to be_a Expressir::Model::DataTypes::Array
        expect(array_type.underlying_type.base_type).to be_a Expressir::Model::DataTypes::Integer
        expect(array_type.underlying_type.bound1.value).to eq "1"
        expect(array_type.underlying_type.bound2.value).to eq "10"
      end

      it "handles enumeration types" do
        expect(enumeration_type.underlying_type).to be_a Expressir::Model::DataTypes::Enumeration
        expect(enumeration_type.underlying_type.items.map(&:id)).to eq [
          "ITEM1", "ITEM2"
        ]
      end

      it "handles select types" do
        expect(select_type.underlying_type).to be_a Expressir::Model::DataTypes::Select
        expect(select_type.underlying_type.items.map(&:id)).to eq ["type1",
                                                                   "type2"]
      end
    end
  end

  describe "where rule handling" do
    context "with different where rule configurations" do
      let(:type_with_single_rule) do
        described_class.new(
          id: "single_rule_type",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
          where_rules: [
            Expressir::Model::Declarations::WhereRule.new(
              id: "WR1",
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
          ],
        )
      end

      let(:type_with_multiple_rules) do
        described_class.new(
          id: "multi_rule_type",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
          where_rules: [
            Expressir::Model::Declarations::WhereRule.new(
              id: "WR1",
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
            Expressir::Model::Declarations::WhereRule.new(
              id: "WR2",
              expression: Expressir::Model::Expressions::BinaryExpression.new(
                operator: "GREATER_THAN",
                operand1: Expressir::Model::References::SimpleReference.new(id: "SELF"),
                operand2: Expressir::Model::Literals::Integer.new(value: "0"),
              ),
            ),
          ],
        )
      end

      let(:type_without_rules) do
        described_class.new(
          id: "no_rules_type",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles single where rule" do
        expect(type_with_single_rule.where_rules.length).to eq 1
        expect(type_with_single_rule.where_rules.first.id).to eq "WR1"
      end

      it "handles multiple where rules" do
        expect(type_with_multiple_rules.where_rules.length).to eq 2
        expect(type_with_multiple_rules.where_rules.map(&:id)).to eq ["WR1",
                                                                      "WR2"]
      end

      it "handles no where rules" do
        expect(type_without_rules.where_rules).to eq([])
      end
    end
  end

  describe "complex type definitions" do
    context "with nested type structures" do
      let(:nested_array_type) do
        described_class.new(
          id: "nested_array",
          underlying_type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Array.new(
              base_type: Expressir::Model::DataTypes::Integer.new,
              bound1: Expressir::Model::Literals::Integer.new(value: "1"),
              bound2: Expressir::Model::Literals::Integer.new(value: "3"),
            ),
            bound1: Expressir::Model::Literals::Integer.new(value: "1"),
            bound2: Expressir::Model::Literals::Integer.new(value: "2"),
          ),
        )
      end

      let(:complex_select_type) do
        described_class.new(
          id: "complex_select",
          underlying_type: Expressir::Model::DataTypes::Select.new(
            items: [
              Expressir::Model::References::SimpleReference.new(id: "type1"),
              Expressir::Model::References::SimpleReference.new(id: "type2"),
            ],
            extensible: true,
          ),
        )
      end

      it "handles nested array types" do
        expect(nested_array_type.underlying_type).to be_a Expressir::Model::DataTypes::Array
        expect(nested_array_type.underlying_type.base_type).to be_a Expressir::Model::DataTypes::Array
        expect(nested_array_type.underlying_type.base_type.base_type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles complex select types" do
        expect(complex_select_type.underlying_type).to be_a Expressir::Model::DataTypes::Select
        expect(complex_select_type.underlying_type.items.length).to eq 2
        expect(complex_select_type.underlying_type.extensible).to be true
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:type_without_underlying) do
        described_class.new(
          id: "no_underlying",
        )
      end

      let(:type_with_empty_id) do
        described_class.new(
          id: "",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:type_with_very_long_id) do
        described_class.new(
          id: "a" * 100,
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:type_with_special_chars) do
        described_class.new(
          id: "type_with_$pecial_chars",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles missing underlying type" do
        expect(type_without_underlying.underlying_type).to be_nil
      end

      it "handles empty identifier" do
        expect(type_with_empty_id.id).to eq ""
      end

      it "handles very long identifier" do
        expect(type_with_very_long_id.id.length).to eq 100
      end

      it "handles special characters in identifier" do
        expect(type_with_special_chars.id).to eq "type_with_$pecial_chars"
      end
    end
  end

  describe "enumeration handling" do
    context "when type has enumeration items" do
      let(:enumeration_type) do
        described_class.new(
          id: "color_type",
          underlying_type: Expressir::Model::DataTypes::Enumeration.new(
            items: [
              Expressir::Model::DataTypes::EnumerationItem.new(
                id: "RED",
                remarks: ["Primary color"],
              ),
              Expressir::Model::DataTypes::EnumerationItem.new(
                id: "GREEN",
                remarks: ["Primary color"],
              ),
              Expressir::Model::DataTypes::EnumerationItem.new(
                id: "BLUE",
                remarks: ["Primary color"],
              ),
            ],
          ),
        )
      end

      it "provides access to enumeration items" do
        expect(enumeration_type.enumeration_items.length).to eq 3
        expect(enumeration_type.enumeration_items.map(&:id)).to eq ["RED",
                                                                    "GREEN", "BLUE"]
      end

      it "maintains enumeration item remarks" do
        expect(enumeration_type.enumeration_items.map(&:remarks)).to all(eq ["Primary color"])
      end
    end
  end

  describe "#children" do
    let(:type) do
      described_class.new(
        id: "test_type",
        underlying_type: Expressir::Model::DataTypes::Integer.new,
        where_rules: [
          Expressir::Model::Declarations::WhereRule.new(id: "WR1"),
          Expressir::Model::Declarations::WhereRule.new(id: "WR2"),
        ],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns all child elements" do
      children_ids = type.children.map(&:id)
      expect(children_ids).to contain_exactly("WR1", "WR2", "remark1",
                                              "remark2")
    end

    context "with enumeration type" do
      let(:enum_type) do
        described_class.new(
          id: "enum_type",
          underlying_type: Expressir::Model::DataTypes::Enumeration.new(
            items: [
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
            ],
          ),
        )
      end

      it "includes enumeration items in children" do
        enum_items = enum_type.enumeration_items
        expect(enum_items.map(&:id)).to eq ["ITEM1", "ITEM2"]
      end
    end

    context "without children" do
      let(:simple_type) do
        described_class.new(
          id: "simple_type",
          underlying_type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "returns empty array" do
        expect(simple_type.children).to be_empty
      end
    end
  end
end
