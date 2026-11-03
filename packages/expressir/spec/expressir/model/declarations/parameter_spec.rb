require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Parameter do
  describe ".new" do
    subject(:parameter) do
      described_class.new(
        id: id,
        var: var,
        type: type,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_param" }
    let(:var) { true }
    let(:type) { Expressir::Model::DataTypes::Integer.new }
    let(:remarks) { ["Test parameter remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a parameter" do
      expect(parameter).to be_a described_class
      expect(parameter.id).to eq "test_param"
      expect(parameter.var).to be true
      expect(parameter.type).to be_a Expressir::Model::DataTypes::Integer
      expect(parameter.remarks).to eq ["Test parameter remark"]
      expect(parameter.remark_items.first.id).to eq "remark1"
    end
  end

  describe "type handling" do
    context "with different parameter types" do
      let(:simple_type_param) do
        described_class.new(
          id: "simple_param",
          type: Expressir::Model::DataTypes::String.new,
        )
      end

      let(:array_type_param) do
        described_class.new(
          id: "array_param",
          type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Integer.new,
            bound1: Expressir::Model::Literals::Integer.new(value: "1"),
            bound2: Expressir::Model::Literals::Integer.new(value: "10"),
          ),
        )
      end

      let(:enum_type_param) do
        described_class.new(
          id: "enum_param",
          type: Expressir::Model::DataTypes::Enumeration.new(
            items: [
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM1"),
              Expressir::Model::DataTypes::EnumerationItem.new(id: "ITEM2"),
            ],
          ),
        )
      end

      let(:entity_type_param) do
        described_class.new(
          id: "entity_param",
          type: Expressir::Model::References::SimpleReference.new(id: "SomeEntity"),
        )
      end

      it "handles simple types" do
        expect(simple_type_param.type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles array types" do
        expect(array_type_param.type).to be_a Expressir::Model::DataTypes::Array
        expect(array_type_param.type.base_type).to be_a Expressir::Model::DataTypes::Integer
        expect(array_type_param.type.bound1.value).to eq "1"
        expect(array_type_param.type.bound2.value).to eq "10"
      end

      it "handles enumeration types" do
        expect(enum_type_param.type).to be_a Expressir::Model::DataTypes::Enumeration
        expect(enum_type_param.type.items.map(&:id)).to eq ["ITEM1", "ITEM2"]
      end

      it "handles entity references" do
        expect(entity_type_param.type).to be_a Expressir::Model::References::SimpleReference
        expect(entity_type_param.type.id).to eq "SomeEntity"
      end
    end
  end

  describe "variable parameters" do
    context "with different var settings" do
      let(:var_param) do
        described_class.new(
          id: "var_param",
          var: true,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:non_var_param) do
        described_class.new(
          id: "non_var_param",
          var: false,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:default_var_param) do
        described_class.new(
          id: "default_param",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles variable parameters" do
        expect(var_param.var).to be true
      end

      it "handles non-variable parameters" do
        expect(non_var_param.var).to be false
      end

      it "handles default var setting" do
        expect(default_var_param.var).to be_nil
      end
    end
  end

  describe "function context" do
    let(:parent_function) do
      Expressir::Model::Declarations::Function.new(
        id: "test_function",
        parameters: [
          described_class.new(
            id: "param1",
            type: Expressir::Model::DataTypes::Integer.new,
          ),
          described_class.new(
            id: "param2",
            type: Expressir::Model::DataTypes::String.new,
          ),
        ],
      )
    end

    it "establishes correct parent relationship" do
      params = parent_function.parameters
      expect(params[0].parent).to eq parent_function
      expect(params[1].parent).to eq parent_function
    end

    it "maintains parameter order" do
      params = parent_function.parameters
      expect(params.map(&:id)).to eq ["param1", "param2"]
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:no_type_param) do
        described_class.new(
          id: "no_type_param",
        )
      end

      let(:empty_id_param) do
        described_class.new(
          id: "",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:complex_type_param) do
        described_class.new(
          id: "complex_param",
          type: Expressir::Model::DataTypes::Set.new(
            base_type: Expressir::Model::DataTypes::Array.new(
              base_type: Expressir::Model::DataTypes::String.new,
              bound1: Expressir::Model::Literals::Integer.new(value: "1"),
              bound2: Expressir::Model::Literals::Integer.new(value: "10"),
            ),
          ),
        )
      end

      it "handles missing type" do
        expect(no_type_param.type).to be_nil
      end

      it "handles empty identifier" do
        expect(empty_id_param.id).to eq ""
      end

      it "handles complex nested types" do
        expect(complex_type_param.type).to be_a Expressir::Model::DataTypes::Set
        expect(complex_type_param.type.base_type).to be_a Expressir::Model::DataTypes::Array
        expect(complex_type_param.type.base_type.base_type).to be_a Expressir::Model::DataTypes::String
      end
    end

    context "with special naming patterns" do
      let(:long_name_param) do
        described_class.new(
          id: "a" * 100,
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:special_chars_param) do
        described_class.new(
          id: "param_with_$pecial_chars",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      let(:numeric_name_param) do
        described_class.new(
          id: "param123",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "handles long identifiers" do
        expect(long_name_param.id.length).to eq 100
      end

      it "handles special characters in identifier" do
        expect(special_chars_param.id).to eq "param_with_$pecial_chars"
      end

      it "handles numeric characters in identifier" do
        expect(numeric_name_param.id).to eq "param123"
      end
    end
  end

  describe "#children" do
    let(:parameter) do
      described_class.new(
        id: "test_param",
        type: Expressir::Model::DataTypes::Integer.new,
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
          Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
        ],
      )
    end

    it "returns all remark items" do
      expect(parameter.children).to contain_exactly(
        have_attributes(id: "remark1"),
        have_attributes(id: "remark2"),
      )
    end

    context "without remark items" do
      let(:simple_parameter) do
        described_class.new(
          id: "simple_param",
          type: Expressir::Model::DataTypes::Integer.new,
        )
      end

      it "returns empty array" do
        expect(simple_parameter.children).to be_empty
      end
    end
  end
end
