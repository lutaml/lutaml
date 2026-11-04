require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Variable do
  let(:integer_type) { Expressir::Model::DataTypes::Integer.new }
  let(:integer_expression) do
    Expressir::Model::Literals::Integer.new(value: "42")
  end

  let(:variable) do
    described_class.new(
      id: "test_var",
      type: integer_type,
      expression: integer_expression,
      remarks: ["First remark", "Second remark"],
      remark_items: [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
      ],
    )
  end

  describe ".new" do
    it "creates a variable with all attributes" do
      expect(variable).to be_a described_class
      expect(variable.id).to eq "test_var"
      expect(variable.type).to be_a Expressir::Model::DataTypes::Integer
      expect(variable.expression).to be_a Expressir::Model::Literals::Integer
      expect(variable.expression.value).to eq "42"
      expect(variable.remarks).to eq ["First remark", "Second remark"]
      expect(variable.remark_items.size).to eq 2
    end

    it "creates a variable without expression" do
      var = described_class.new(
        id: "test_var",
        type: integer_type,
      )
      expect(var.id).to eq "test_var"
      expect(var.type).to be_a Expressir::Model::DataTypes::Integer
      expect(var.expression).to be_nil
    end

    it "creates a variable with minimal attributes" do
      var = described_class.new(id: "test_var")
      expect(var.id).to eq "test_var"
      expect(var.type).to be_nil
      expect(var.expression).to be_nil
      expect(var.remarks).to eq([])
      expect(var.remark_items).to eq([])
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(variable).to be_a Expressir::Model::ModelElement
    end

    it "includes Identifier module" do
      expect(described_class.included_modules).to include(Expressir::Model::Identifier)
    end
  end

  describe "#children" do
    it "returns remark items" do
      expect(variable.children).to match_array(variable.remark_items)
    end

    it "returns empty array when no remark items" do
      var = described_class.new(id: "test_var")
      expect(var.children).to be_empty
    end
  end

  describe "in context" do
    let(:function) do
      Expressir::Model::Declarations::Function.new(
        id: "test_function",
        variables: [variable],
      )
    end

    let(:procedure) do
      Expressir::Model::Declarations::Procedure.new(
        id: "test_procedure",
        variables: [variable],
      )
    end

    it "can be used in functions" do
      expect(function.variables).to include(variable)
    end

    it "can be used in procedures" do
      expect(procedure.variables).to include(variable)
    end

    it "sets parent relationship" do
      expect(function.variables.first.parent).to eq function
      expect(procedure.variables.first.parent).to eq procedure
    end
  end

  describe "with different types" do
    let(:string_type) { Expressir::Model::DataTypes::String.new }
    let(:real_type) { Expressir::Model::DataTypes::Real.new }
    let(:boolean_type) { Expressir::Model::DataTypes::Boolean.new }

    it "supports string type" do
      var = described_class.new(
        id: "str_var",
        type: string_type,
      )
      expect(var.type).to be_a Expressir::Model::DataTypes::String
    end

    it "supports real type" do
      var = described_class.new(
        id: "real_var",
        type: real_type,
      )
      expect(var.type).to be_a Expressir::Model::DataTypes::Real
    end

    it "supports boolean type" do
      var = described_class.new(
        id: "bool_var",
        type: boolean_type,
      )
      expect(var.type).to be_a Expressir::Model::DataTypes::Boolean
    end
  end

  describe "with different expressions" do
    let(:string_literal) do
      Expressir::Model::Literals::String.new(value: "test")
    end
    let(:real_literal) { Expressir::Model::Literals::Real.new(value: "3.14") }
    let(:logical_literal) do
      Expressir::Model::Literals::Logical.new(value: "TRUE")
    end

    it "supports string expressions" do
      var = described_class.new(
        id: "str_var",
        expression: string_literal,
      )
      expect(var.expression).to be_a Expressir::Model::Literals::String
      expect(var.expression.value).to eq "test"
    end

    it "supports real expressions" do
      var = described_class.new(
        id: "real_var",
        expression: real_literal,
      )
      expect(var.expression).to be_a Expressir::Model::Literals::Real
      expect(var.expression.value).to eq "3.14"
    end

    it "supports logical expressions" do
      var = described_class.new(
        id: "bool_var",
        expression: logical_literal,
      )
      expect(var.expression).to be_a Expressir::Model::Literals::Logical
      expect(var.expression.value).to eq "TRUE"
    end
  end
end
