require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Entity do
  describe ".new" do
    subject(:entity) do
      described_class.new(
        id: id,
        abstract: abstract,
        supertype_expression: supertype_expression,
        subtype_of: subtype_of,
        attributes: attributes,
        unique_rules: unique_rules,
        where_rules: where_rules,
        remarks: remarks,
        remark_items: remark_items,
        informal_propositions: informal_propositions,
      )
    end

    let(:id) { "test_entity" }
    let(:abstract) { true }
    let(:supertype_expression) { nil }
    let(:subtype_of) { [] }
    let(:attributes) { [] }
    let(:unique_rules) { [] }
    let(:where_rules) { [] }
    let(:remarks) { ["Test entity remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end
    let(:informal_propositions) do
      [
        Expressir::Model::Declarations::InformalPropositionRule.new(id: "IP1",
                                                                    remarks: ["First proposition"]),
      ]
    end

    it "creates an entity" do
      expect(entity).to be_a described_class
      expect(entity.id).to eq "test_entity"
      expect(entity.abstract).to be true
      expect(entity.remarks).to eq ["Test entity remark"]
      expect(entity.informal_propositions.first.remarks).to eq ["First proposition"]
    end
  end

  describe "inheritance hierarchy" do
    context "with different inheritance patterns" do
      let(:base_entity) do
        described_class.new(
          id: "base_entity",
          attributes: [
            Expressir::Model::Declarations::Attribute.new(
              id: "base_attr",
              kind: Expressir::Model::Declarations::Attribute::EXPLICIT,
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
        )
      end

      let(:subtype_entity) do
        described_class.new(
          id: "subtype_entity",
          subtype_of: [
            Expressir::Model::References::SimpleReference.new(id: "base_entity"),
          ],
        )
      end

      let(:multiple_inheritance_entity) do
        described_class.new(
          id: "multiple_inheritance",
          subtype_of: [
            Expressir::Model::References::SimpleReference.new(id: "base_entity"),
            Expressir::Model::References::SimpleReference.new(id: "other_entity"),
          ],
        )
      end

      let(:abstract_supertype_entity) do
        described_class.new(
          id: "abstract_super",
          abstract: true,
          supertype_expression: Expressir::Model::References::SimpleReference.new(id: "subtype_entity"),
        )
      end

      it "handles base entities" do
        expect(base_entity.subtype_of).to eq([])
        expect(base_entity.attributes.first.id).to eq "base_attr"
      end

      it "handles single inheritance" do
        expect(subtype_entity.subtype_of.first.id).to eq "base_entity"
      end

      it "handles multiple inheritance" do
        expect(multiple_inheritance_entity.subtype_of.map(&:id)).to eq [
          "base_entity", "other_entity"
        ]
      end

      it "handles abstract supertypes" do
        expect(abstract_supertype_entity.abstract).to be true
        expect(abstract_supertype_entity.supertype_expression.id).to eq "subtype_entity"
      end
    end
  end

  describe "attribute handling" do
    context "with different attribute types" do
      let(:entity_with_attributes) do
        described_class.new(
          id: "test_entity",
          attributes: [
            Expressir::Model::Declarations::Attribute.new(
              id: "explicit_attr",
              kind: Expressir::Model::Declarations::Attribute::EXPLICIT,
              type: Expressir::Model::DataTypes::String.new,
            ),
            Expressir::Model::Declarations::Attribute.new(
              id: "derived_attr",
              kind: Expressir::Model::Declarations::Attribute::DERIVED,
              type: Expressir::Model::DataTypes::Integer.new,
              expression: Expressir::Model::Literals::Integer.new(value: "42"),
            ),
            Expressir::Model::Declarations::Attribute.new(
              id: "inverse_attr",
              kind: Expressir::Model::Declarations::Attribute::INVERSE,
              type: Expressir::Model::References::SimpleReference.new(id: "other_entity"),
              expression: Expressir::Model::References::SimpleReference.new(id: "other_attr"),
            ),
          ],
        )
      end

      let(:optional_attributes_entity) do
        described_class.new(
          id: "optional_entity",
          attributes: [
            Expressir::Model::Declarations::Attribute.new(
              id: "optional_attr",
              kind: Expressir::Model::Declarations::Attribute::EXPLICIT,
              optional: true,
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
        )
      end

      it "handles different attribute kinds" do
        expect(entity_with_attributes.attributes.map(&:kind)).to eq %w[EXPLICIT
                                                                       DERIVED INVERSE]
      end

      it "handles explicit attributes" do
        explicit_attr = entity_with_attributes.attributes.first
        expect(explicit_attr.kind).to eq "EXPLICIT"
        expect(explicit_attr.type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles derived attributes" do
        derived_attr = entity_with_attributes.attributes[1]
        expect(derived_attr.kind).to eq "DERIVED"
        expect(derived_attr.id).to eq "derived_attr"
        expect(derived_attr.expression.value).to eq "42"
      end

      it "handles inverse attributes" do
        inverse_attr = entity_with_attributes.attributes.last
        expect(inverse_attr.kind).to eq "INVERSE"
        expect(inverse_attr.expression.id).to eq "other_attr"
      end

      it "handles optional attributes" do
        expect(optional_attributes_entity.attributes.first.optional).to be true
      end
    end
  end

  describe "rules and constraints" do
    context "with various rules" do
      let(:entity_with_rules) do
        described_class.new(
          id: "rule_entity",
          attributes: [
            Expressir::Model::Declarations::Attribute.new(
              id: "test_attr",
              kind: Expressir::Model::Declarations::Attribute::EXPLICIT,
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
          unique_rules: [
            Expressir::Model::Declarations::UniqueRule.new(
              id: "UR1",
              attributes: [
                Expressir::Model::References::SimpleReference.new(id: "test_attr"),
              ],
            ),
          ],
          where_rules: [
            Expressir::Model::Declarations::WhereRule.new(
              id: "WR1",
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
          ],
        )
      end

      let(:multiple_rules_entity) do
        described_class.new(
          id: "multi_rule_entity",
          unique_rules: [
            Expressir::Model::Declarations::UniqueRule.new(id: "UR1"),
            Expressir::Model::Declarations::UniqueRule.new(id: "UR2"),
          ],
          where_rules: [
            Expressir::Model::Declarations::WhereRule.new(id: "WR1"),
            Expressir::Model::Declarations::WhereRule.new(id: "WR2"),
          ],
        )
      end

      it "handles unique rules" do
        expect(entity_with_rules.unique_rules.first.id).to eq "UR1"
        expect(entity_with_rules.unique_rules.first.attributes.first.id).to eq "test_attr"
      end

      it "handles where rules" do
        expect(entity_with_rules.where_rules.first.id).to eq "WR1"
        expect(entity_with_rules.where_rules.first.expression.value).to eq "TRUE"
      end

      it "handles multiple rules" do
        expect(multiple_rules_entity.unique_rules.map(&:id)).to eq ["UR1",
                                                                    "UR2"]
        expect(multiple_rules_entity.where_rules.map(&:id)).to eq ["WR1", "WR2"]
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:empty_entity) do
        described_class.new(
          id: "empty_entity",
        )
      end

      let(:circular_inheritance) do
        entity1 = described_class.new(
          id: "entity1",
          subtype_of: [Expressir::Model::References::SimpleReference.new(id: "entity2")],
        )
        described_class.new(
          id: "entity2",
          subtype_of: [Expressir::Model::References::SimpleReference.new(id: "entity1")],
        )
        entity1
      end

      let(:complex_supertype_expression) do
        described_class.new(
          id: "complex_super",
          supertype_expression: Expressir::Model::SupertypeExpressions::BinarySupertypeExpression.new(
            operator: "AND",
            operand1: Expressir::Model::References::SimpleReference.new(id: "entity1"),
            operand2: Expressir::Model::References::SimpleReference.new(id: "entity2"),
          ),
        )
      end

      it "handles empty entities" do
        expect(empty_entity.attributes).to eq([])
        expect(empty_entity.unique_rules).to eq([])
        expect(empty_entity.where_rules).to eq([])
      end

      it "handles circular inheritance" do
        expect(circular_inheritance.subtype_of.first.id).to eq "entity2"
      end

      it "handles complex supertype expressions" do
        expect(complex_supertype_expression.supertype_expression).to be_a Expressir::Model::SupertypeExpressions::BinarySupertypeExpression
        expect(complex_supertype_expression.supertype_expression.operator).to eq "AND"
      end
    end
  end

  describe "#children" do
    let(:entity) do
      described_class.new(
        id: "test_entity",
        attributes: [
          Expressir::Model::Declarations::Attribute.new(id: "attr1"),
          Expressir::Model::Declarations::Attribute.new(id: "attr2"),
        ],
        unique_rules: [
          Expressir::Model::Declarations::UniqueRule.new(id: "UR1"),
        ],
        where_rules: [
          Expressir::Model::Declarations::WhereRule.new(id: "WR1"),
        ],
        informal_propositions: [
          Expressir::Model::Declarations::InformalPropositionRule.new(id: "IP1"),
        ],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        ],
      )
    end

    it "returns all child elements" do
      children_ids = entity.children.map(&:id)
      expect(children_ids).to contain_exactly(
        "attr1", "attr2", "UR1", "WR1", "IP1", "remark1"
      )
    end

    context "with empty entity" do
      let(:empty_entity) { described_class.new(id: "empty_entity") }

      it "returns empty array for entity without children" do
        expect(empty_entity.children).to be_empty
      end
    end
  end
end
