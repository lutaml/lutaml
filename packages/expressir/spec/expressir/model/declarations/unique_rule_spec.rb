require "spec_helper"

RSpec.describe Expressir::Model::Declarations::UniqueRule do
  describe ".new" do
    subject(:unique_rule) do
      described_class.new(
        id: id,
        attributes: attributes,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_unique_rule" }
    let(:attributes) do
      [
        Expressir::Model::References::SimpleReference.new(id: "attr1"),
        Expressir::Model::References::SimpleReference.new(id: "attr2"),
      ]
    end
    let(:remarks) { ["Test unique rule remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a unique rule" do
      expect(unique_rule).to be_a described_class
      expect(unique_rule.id).to eq "test_unique_rule"
      expect(unique_rule.attributes.map(&:id)).to eq ["attr1", "attr2"]
      expect(unique_rule.remarks).to eq ["Test unique rule remark"]
      expect(unique_rule.remark_items.first.id).to eq "remark1"
    end
  end

  describe "attribute handling" do
    context "with different attribute configurations" do
      let(:single_attribute_rule) do
        described_class.new(
          id: "single_attr",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      let(:multiple_attributes_rule) do
        described_class.new(
          id: "multi_attr",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
            Expressir::Model::References::SimpleReference.new(id: "attr2"),
            Expressir::Model::References::SimpleReference.new(id: "attr3"),
          ],
        )
      end

      let(:complex_attribute_references) do
        described_class.new(
          id: "complex_attr",
          attributes: [
            Expressir::Model::References::AttributeReference.new(
              ref: Expressir::Model::References::SimpleReference.new(id: "entity1"),
              attribute: Expressir::Model::References::SimpleReference.new(id: "attr1"),
            ),
            Expressir::Model::References::AttributeReference.new(
              ref: Expressir::Model::References::SimpleReference.new(id: "entity2"),
              attribute: Expressir::Model::References::SimpleReference.new(id: "attr2"),
            ),
          ],
        )
      end

      it "handles single attribute" do
        expect(single_attribute_rule.attributes.length).to eq 1
        expect(single_attribute_rule.attributes.first.id).to eq "attr1"
      end

      it "handles multiple attributes" do
        expect(multiple_attributes_rule.attributes.length).to eq 3
        expect(multiple_attributes_rule.attributes.map(&:id)).to eq ["attr1",
                                                                     "attr2", "attr3"]
      end

      it "handles complex attribute references" do
        expect(complex_attribute_references.attributes[0]).to be_a Expressir::Model::References::AttributeReference
        expect(complex_attribute_references.attributes[0].ref.id).to eq "entity1"
        expect(complex_attribute_references.attributes[0].attribute.id).to eq "attr1"
        expect(complex_attribute_references.attributes[1].ref.id).to eq "entity2"
        expect(complex_attribute_references.attributes[1].attribute.id).to eq "attr2"
      end
    end
  end

  describe "entity context" do
    context "with parent entity" do
      let(:parent_entity) do
        Expressir::Model::Declarations::Entity.new(
          id: "test_entity",
          attributes: [
            Expressir::Model::Declarations::Attribute.new(
              id: "attr1",
              type: Expressir::Model::DataTypes::String.new,
            ),
            Expressir::Model::Declarations::Attribute.new(
              id: "attr2",
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
          unique_rules: [
            described_class.new(
              id: "UR1",
              attributes: [
                Expressir::Model::References::SimpleReference.new(id: "attr1"),
                Expressir::Model::References::SimpleReference.new(id: "attr2"),
              ],
            ),
          ],
        )
      end

      it "establishes correct parent relationship" do
        unique_rule = parent_entity.unique_rules.first
        expect(unique_rule.parent).to eq parent_entity
      end

      it "references existing entity attributes" do
        unique_rule = parent_entity.unique_rules.first
        attribute_ids = unique_rule.attributes.map(&:id)
        entity_attribute_ids = parent_entity.attributes.map(&:id)
        expect(attribute_ids - entity_attribute_ids).to be_empty
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:empty_rule) do
        described_class.new(
          id: "empty_rule",
        )
      end

      let(:no_id_rule) do
        described_class.new(
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      let(:empty_attributes_rule) do
        described_class.new(
          id: "no_attrs",
          attributes: [],
        )
      end

      let(:duplicate_attributes_rule) do
        described_class.new(
          id: "duplicate_attrs",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      it "handles empty rule" do
        expect(empty_rule.attributes).to eq([])
      end

      it "handles missing id" do
        expect(no_id_rule.id).to be_nil
        expect(no_id_rule.attributes.first.id).to eq "attr1"
      end

      it "handles empty attributes array" do
        expect(empty_attributes_rule.attributes).to be_empty
      end

      it "handles duplicate attributes" do
        expect(duplicate_attributes_rule.attributes.map(&:id)).to eq ["attr1",
                                                                      "attr1"]
      end
    end

    context "with special naming patterns" do
      let(:long_name_rule) do
        described_class.new(
          id: "a" * 100,
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      let(:special_chars_rule) do
        described_class.new(
          id: "rule_with_$pecial_chars",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      let(:numeric_name_rule) do
        described_class.new(
          id: "rule123",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      it "handles long identifiers" do
        expect(long_name_rule.id.length).to eq 100
      end

      it "handles special characters in identifier" do
        expect(special_chars_rule.id).to eq "rule_with_$pecial_chars"
      end

      it "handles numeric characters in identifier" do
        expect(numeric_name_rule.id).to eq "rule123"
      end
    end
  end

  describe "#children" do
    let(:unique_rule) do
      described_class.new(
        id: "test_rule",
        attributes: [
          Expressir::Model::References::SimpleReference.new(id: "attr1"),
          Expressir::Model::References::SimpleReference.new(id: "attr2"),
        ],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns all remark items" do
      expect(unique_rule.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "without remark items" do
      let(:simple_rule) do
        described_class.new(
          id: "simple_rule",
          attributes: [
            Expressir::Model::References::SimpleReference.new(id: "attr1"),
          ],
        )
      end

      it "returns empty array" do
        expect(simple_rule.children).to be_empty
      end
    end
  end
end
