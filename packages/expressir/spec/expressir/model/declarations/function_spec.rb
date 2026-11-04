require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Function do
  describe ".new" do
    subject(:function) do
      described_class.new(
        id: id,
        parameters: parameters,
        return_type: return_type,
        types: types,
        entities: entities,
        subtype_constraints: subtype_constraints,
        functions: functions,
        procedures: procedures,
        constants: constants,
        variables: variables,
        statements: statements,
        remarks: remarks,
        remark_items: remark_items,
      )
    end

    let(:id) { "test_function" }
    let(:parameters) do
      [
        Expressir::Model::Declarations::Parameter.new(
          id: "param1",
          type: Expressir::Model::DataTypes::Integer.new,
        ),
      ]
    end
    let(:return_type) { Expressir::Model::DataTypes::Boolean.new }
    let(:types) { [] }
    let(:entities) { [] }
    let(:subtype_constraints) { [] }
    let(:functions) { [] }
    let(:procedures) { [] }
    let(:constants) { [] }
    let(:variables) { [] }
    let(:statements) do
      [
        Expressir::Model::Statements::Return.new(
          expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
        ),
      ]
    end
    let(:remarks) { ["Test function remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a function" do
      expect(function).to be_a described_class
      expect(function.id).to eq "test_function"
      expect(function.parameters.first.id).to eq "param1"
      expect(function.return_type).to be_a Expressir::Model::DataTypes::Boolean
      expect(function.statements.first).to be_a Expressir::Model::Statements::Return
      expect(function.remarks).to eq ["Test function remark"]
    end
  end

  describe "parameter handling" do
    context "with different parameter configurations" do
      let(:no_params_function) do
        described_class.new(
          id: "no_params",
          return_type: Expressir::Model::DataTypes::Boolean.new,
        )
      end

      let(:multiple_params_function) do
        described_class.new(
          id: "multi_params",
          parameters: [
            Expressir::Model::Declarations::Parameter.new(
              id: "param1",
              type: Expressir::Model::DataTypes::Integer.new,
            ),
            Expressir::Model::Declarations::Parameter.new(
              id: "param2",
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
          return_type: Expressir::Model::DataTypes::Boolean.new,
        )
      end

      let(:optional_params_function) do
        described_class.new(
          id: "optional_params",
          parameters: [
            Expressir::Model::Declarations::Parameter.new(
              id: "param1",
              type: Expressir::Model::DataTypes::Integer.new,
              var: true,
            ),
          ],
          return_type: Expressir::Model::DataTypes::Boolean.new,
        )
      end

      it "handles functions without parameters" do
        expect(no_params_function.parameters).to eq([])
      end

      it "handles multiple parameters" do
        expect(multiple_params_function.parameters.map(&:id)).to eq ["param1",
                                                                     "param2"]
        expect(multiple_params_function.parameters.first.type).to be_a Expressir::Model::DataTypes::Integer
        expect(multiple_params_function.parameters.last.type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles optional parameters" do
        expect(optional_params_function.parameters.first.var).to be true
      end
    end
  end

  describe "local declarations" do
    context "with different local declarations" do
      let(:function_with_locals) do
        described_class.new(
          id: "func_with_locals",
          return_type: Expressir::Model::DataTypes::Boolean.new,
          types: [
            Expressir::Model::Declarations::Type.new(
              id: "local_type",
              underlying_type: Expressir::Model::DataTypes::String.new,
            ),
          ],
          entities: [
            Expressir::Model::Declarations::Entity.new(
              id: "local_entity",
            ),
          ],
          constants: [
            Expressir::Model::Declarations::Constant.new(
              id: "local_const",
              type: Expressir::Model::DataTypes::Integer.new,
              expression: Expressir::Model::Literals::Integer.new(value: "42"),
            ),
          ],
          variables: [
            Expressir::Model::Declarations::Variable.new(
              id: "local_var",
              type: Expressir::Model::DataTypes::String.new,
            ),
          ],
        )
      end

      let(:nested_functions) do
        described_class.new(
          id: "outer_func",
          return_type: Expressir::Model::DataTypes::Boolean.new,
          functions: [
            described_class.new(
              id: "inner_func",
              return_type: Expressir::Model::DataTypes::Integer.new,
            ),
          ],
          procedures: [
            Expressir::Model::Declarations::Procedure.new(
              id: "inner_proc",
            ),
          ],
        )
      end

      it "handles local type declarations" do
        expect(function_with_locals.types.first.id).to eq "local_type"
        expect(function_with_locals.types.first.underlying_type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles local entity declarations" do
        expect(function_with_locals.entities.first.id).to eq "local_entity"
      end

      it "handles local constant declarations" do
        expect(function_with_locals.constants.first.id).to eq "local_const"
        expect(function_with_locals.constants.first.expression.value).to eq "42"
      end

      it "handles local variable declarations" do
        expect(function_with_locals.variables.first.id).to eq "local_var"
        expect(function_with_locals.variables.first.type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles nested functions and procedures" do
        expect(nested_functions.functions.first.id).to eq "inner_func"
        expect(nested_functions.procedures.first.id).to eq "inner_proc"
      end
    end
  end

  describe "statement handling" do
    context "with different statement types" do
      let(:function_with_statements) do
        described_class.new(
          id: "func_with_statements",
          return_type: Expressir::Model::DataTypes::Boolean.new,
          variables: [
            Expressir::Model::Declarations::Variable.new(
              id: "test_var",
              type: Expressir::Model::DataTypes::Boolean.new,
            ),
          ],
          statements: [
            Expressir::Model::Statements::Assignment.new(
              ref: Expressir::Model::References::SimpleReference.new(id: "test_var"),
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
            ),
            Expressir::Model::Statements::If.new(
              expression: Expressir::Model::References::SimpleReference.new(id: "test_var"),
              statements: [
                Expressir::Model::Statements::Return.new(
                  expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
                ),
              ],
              else_statements: [
                Expressir::Model::Statements::Return.new(
                  expression: Expressir::Model::Literals::Logical.new(value: "FALSE"),
                ),
              ],
            ),
          ],
        )
      end

      let(:complex_statements_function) do
        described_class.new(
          id: "complex_func",
          return_type: Expressir::Model::DataTypes::Integer.new,
          statements: [
            Expressir::Model::Statements::Case.new(
              expression: Expressir::Model::Literals::Integer.new(value: "1"),
              actions: [
                Expressir::Model::Statements::CaseAction.new(
                  labels: [Expressir::Model::Literals::Integer.new(value: "1")],
                  statement: Expressir::Model::Statements::Return.new(
                    expression: Expressir::Model::Literals::Integer.new(value: "42"),
                  ),
                ),
              ],
            ),
            Expressir::Model::Statements::Repeat.new(
              statements: [
                Expressir::Model::Statements::Skip.new,
              ],
            ),
          ],
        )
      end

      it "handles basic statements" do
        expect(function_with_statements.statements.first).to be_a Expressir::Model::Statements::Assignment
        expect(function_with_statements.statements.last).to be_a Expressir::Model::Statements::If
      end

      it "handles complex control flow statements" do
        expect(complex_statements_function.statements.first).to be_a Expressir::Model::Statements::Case
        expect(complex_statements_function.statements.last).to be_a Expressir::Model::Statements::Repeat
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:minimal_function) do
        described_class.new(
          id: "minimal_func",
          return_type: Expressir::Model::DataTypes::Boolean.new,
        )
      end

      let(:empty_body_function) do
        described_class.new(
          id: "empty_body",
          return_type: Expressir::Model::DataTypes::Boolean.new,
          statements: [
            Expressir::Model::Statements::Null.new,
          ],
        )
      end

      let(:complex_return_type) do
        described_class.new(
          id: "complex_return",
          return_type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::DataTypes::Set.new(
              base_type: Expressir::Model::DataTypes::String.new,
            ),
          ),
        )
      end

      it "handles minimal function definition" do
        expect(minimal_function.parameters).to eq([])
        expect(minimal_function.statements).to eq([])
      end

      it "handles empty function body" do
        expect(empty_body_function.statements.first).to be_a Expressir::Model::Statements::Null
      end

      it "handles complex return types" do
        expect(complex_return_type.return_type).to be_a Expressir::Model::DataTypes::Array
        expect(complex_return_type.return_type.base_type).to be_a Expressir::Model::DataTypes::Set
        expect(complex_return_type.return_type.base_type.base_type).to be_a Expressir::Model::DataTypes::String
      end
    end
  end

  describe "#children" do
    let(:function) do
      described_class.new(
        id: "test_function",
        parameters: [
          Expressir::Model::Declarations::Parameter.new(id: "param1"),
        ],
        types: [
          Expressir::Model::Declarations::Type.new(id: "type1"),
        ],
        entities: [
          Expressir::Model::Declarations::Entity.new(id: "entity1"),
        ],
        constants: [
          Expressir::Model::Declarations::Constant.new(id: "const1"),
        ],
        variables: [
          Expressir::Model::Declarations::Variable.new(id: "var1"),
        ],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        ],
      )
    end

    it "returns all child elements" do
      children_ids = function.children.map(&:id)
      expect(children_ids).to contain_exactly(
        "param1", "type1", "entity1", "const1", "var1", "remark1"
      )
    end

    context "with enumeration items" do
      let(:function_with_enum) do
        described_class.new(
          id: "func_with_enum",
          types: [
            Expressir::Model::Declarations::Type.new(
              id: "enum_type",
              underlying_type: Expressir::Model::DataTypes::Enumeration.new(
                items: [
                  Expressir::Model::DataTypes::EnumerationItem.new(id: "ENUM1"),
                  Expressir::Model::DataTypes::EnumerationItem.new(id: "ENUM2"),
                ],
              ),
            ),
          ],
        )
      end

      it "includes enumeration items in children" do
        type = function_with_enum.types.first
        enum_items = type.enumeration_items
        expect(enum_items.map(&:id)).to eq ["ENUM1", "ENUM2"]
      end
    end
  end
end
