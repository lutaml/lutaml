require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Attribute do
  describe ".new" do
    subject(:attribute) do
      described_class.new(
        id: id,
        kind: kind,
        supertype_attribute: supertype_attribute,
        optional: optional,
        type: type,
        expression: expression,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_attribute" }
    let(:kind) { described_class::EXPLICIT }
    let(:supertype_attribute) { nil }
    let(:optional) { true }
    let(:type) { Expressir::Model::DataTypes::String.new }
    let(:expression) { nil }
    let(:remarks) { ["Test remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates an explicit attribute" do
      expect(attribute).to be_a described_class
      expect(attribute.id).to eq "test_attribute"
      expect(attribute.kind).to eq "EXPLICIT"
      expect(attribute.optional).to be true
      expect(attribute.type).to be_a Expressir::Model::DataTypes::String
      expect(attribute.remarks).to eq ["Test remark"]
    end
  end

  describe "attribute kinds" do
    context "with different kinds" do
      let(:explicit_attr) do
        described_class.new(
          id: "explicit_attr",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:derived_attr) do
        described_class.new(
          id: "derived_attr",
          kind: described_class::DERIVED,
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      let(:inverse_attr) do
        described_class.new(
          id: "inverse_attr",
          kind: described_class::INVERSE,
          type: Expressir::Model::DataTypes::String.new,
          expression: Expressir::Model::References::SimpleReference.new(id: "other_attr"),
        )
      end

      it "handles explicit attributes" do
        expect(explicit_attr.kind).to eq "EXPLICIT"
        expect(explicit_attr.expression).to be_nil
      end

      it "handles derived attributes" do
        expect(derived_attr.kind).to eq "DERIVED"
        expect(derived_attr.expression.value).to eq "42"
      end

      it "handles inverse attributes" do
        expect(inverse_attr.kind).to eq "INVERSE"
        expect(inverse_attr.expression.id).to eq "other_attr"
      end
    end
  end

  describe "type handling" do
    context "with different types" do
      let(:simple_type_attr) do
        described_class.new(
          id: "simple_attr",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:array_type_attr) do
        described_class.new(
          id: "array_attr",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
            bound1: Expressir::Model::Literals::Integer.new(value: "1"),
            bound2: Expressir::Model::Literals::Integer.new(value: "10"),
          ),
        )
      end

      let(:enum_type_attr) do
        described_class.new(
          id: "enum_attr",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::Enumeration.new(
            items: [
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
            ],
          ),
        )
      end

      it "handles simple types" do
        expect(simple_type_attr.type).to be_a Expressir::Model::DataTypes::Integer
      end

      it "handles array types" do
        expect(array_type_attr.type).to be_a Expressir::Model::DataTypes::Array
        expect(array_type_attr.type.base_type).to be_a Expressir::Model::DataTypes::Integer
        expect(array_type_attr.type.bound1.value).to eq "1"
        expect(array_type_attr.type.bound2.value).to eq "10"
      end

      it "handles enumeration types" do
        expect(enum_type_attr.type).to be_a Expressir::Model::DataTypes::Enumeration
        expect(enum_type_attr.type.items.map(&:id)).to eq ["ITEM1", "ITEM2"]
      end
    end
  end

  describe "inheritance handling" do
    context "with supertype attributes" do
      let(:supertype_ref) do
        Expressir::Model::References::AttributeReference.new(
          ref: Expressir::Model::References::GroupReference.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "SELF"),
            entity: Expressir::Model::References::SimpleReference.new(id: "parent_entity"),
          ),
          attribute: Expressir::Model::References::SimpleReference.new(id: "parent_attr"),
        )
      end

      let(:redeclared_attr) do
        described_class.new(
          kind: described_class::EXPLICIT,
          supertype_attribute: supertype_ref,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:renamed_attr) do
        described_class.new(
          id: "new_name",
          kind: described_class::EXPLICIT,
          supertype_attribute: supertype_ref,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles redeclared attributes" do
        expect(redeclared_attr.supertype_attribute).to eq supertype_ref
        expect(redeclared_attr.supertype_attribute.attribute.id).to eq "parent_attr"
      end

      it "handles renamed attributes" do
        expect(renamed_attr.id).to eq "new_name"
        expect(renamed_attr.supertype_attribute.attribute.id).to eq "parent_attr"
      end
    end
  end

  describe "edge cases" do
    context "with invalid configurations" do
      let(:no_type_attr) do
        described_class.new(
          id: "no_type",
          kind: described_class::EXPLICIT,
        )
      end

      let(:derived_no_expr_attr) do
        described_class.new(
          id: "derived_no_expr",
          kind: described_class::DERIVED,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:explicit_with_expr_attr) do
        described_class.new(
          id: "explicit_with_expr",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::Integer.new,
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        )
      end

      it "handles missing type" do
        expect(no_type_attr.type).to be_nil
      end

      it "handles derived attribute without expression" do
        expect(derived_no_expr_attr.expression).to be_nil
      end

      it "handles explicit attribute with expression" do
        expect(explicit_with_expr_attr.expression.value).to eq "42"
      end
    end

    context "with unusual values" do
      let(:empty_id_attr) do
        described_class.new(
          id: "",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:long_id_attr) do
        described_class.new(
          id: "a" * 100,
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:special_chars_attr) do
        described_class.new(
          id: "attr_with_$pecial_chars",
          kind: described_class::EXPLICIT,
          type: Expressir::Model::DataTypes::String.new,
        )
      end

      it "handles empty identifier" do
        expect(empty_id_attr.id).to eq ""
      end

      it "handles long identifier" do
        expect(long_id_attr.id.length).to eq 100
      end

      it "handles special characters in identifier" do
        expect(special_chars_attr.id).to eq "attr_with_$pecial_chars"
      end
    end
  end

  describe "#children" do
    let(:attribute) do
      described_class.new(
        id: "test_attr",
        kind: described_class::EXPLICIT,
        type: Expressir::Model::DataTypes::String.new,
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns remark items" do
      expect(attribute.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end
  end
end
