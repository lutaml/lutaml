require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Procedure do
  describe ".new" do
    subject(:procedure) do
      described_class.new(
        id: id,
        parameters: parameters,
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

    let(:id) { "test_procedure" }
    let(:parameters) do
      [
        Expressir::Model::Declarations::Parameter.new(
          id: "param1",
          type: Expressir::Model::DataTypes::Integer.new,
        ),
      ]
    end
    let(:types) { [] }
    let(:entities) { [] }
    let(:subtype_constraints) { [] }
    let(:functions) { [] }
    let(:procedures) { [] }
    let(:constants) { [] }
    let(:variables) { [] }
    let(:statements) do
      [
        Expressir::Model::Statements::Assignment.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "param1"),
          expression: Expressir::Model::Literals::Integer.new(value: "42"),
        ),
      ]
    end
    let(:remarks) { ["Test procedure remark"] }
    let(:remark_items) do
      [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ]
    end

    it "creates a procedure" do
      expect(procedure).to be_a described_class
      expect(procedure.id).to eq "test_procedure"
      expect(procedure.parameters.first.id).to eq "param1"
      expect(procedure.statements.first).to be_a Expressir::Model::Statements::Assignment
      expect(procedure.remarks).to eq ["Test procedure remark"]
      expect(procedure.remark_items.first.id).to eq "remark1"
    end
  end

  describe "parameter handling" do
    context "with different parameter configurations" do
      let(:no_params_procedure) do
        described_class.new(
          id: "no_params_proc",
        )
      end

      let(:multiple_params_procedure) do
        described_class.new(
          id: "multi_params_proc",
          parameters: [
            Expressir::Model::Declarations::Parameter.new(
              id: "param1",
              type: Expressir::Model::DataTypes::Integer.new,
            ),
            Expressir::Model::Declarations::Parameter.new(
              id: "param2",
              type: Expressir::Model::DataTypes::String.new,
              var: true,
            ),
          ],
        )
      end

      let(:complex_params_procedure) do
        described_class.new(
          id: "complex_params_proc",
          parameters: [
            Expressir::Model::Declarations::Parameter.new(
              id: "array_param",
              type: Expressir::Model::DataTypes::Array.new(
                base_type: Expressir::Model::DataTypes::Integer.new,
                bound1: Expressir::Model::Literals::Integer.new(value: "1"),
                bound2: Expressir::Model::Literals::Integer.new(value: "10"),
              ),
            ),
          ],
        )
      end

      it "handles procedures without parameters" do
        expect(no_params_procedure.parameters).to eq([])
      end

      it "handles multiple parameters" do
        params = multiple_params_procedure.parameters
        expect(params.map(&:id)).to eq ["param1", "param2"]
        expect(params[0].type).to be_a Expressir::Model::DataTypes::Integer
        expect(params[1].type).to be_a Expressir::Model::DataTypes::String
        expect(params[1].var).to be true
      end

      it "handles complex parameter types" do
        param = complex_params_procedure.parameters.first
        expect(param.type).to be_a Expressir::Model::DataTypes::Array
        expect(param.type.base_type).to be_a Expressir::Model::DataTypes::Integer
        expect(param.type.bound1.value).to eq "1"
        expect(param.type.bound2.value).to eq "10"
      end
    end
  end

  describe "local declarations" do
    context "with various local declarations" do
      let(:procedure_with_locals) do
        described_class.new(
          id: "proc_with_locals",
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

      let(:nested_procedures) do
        described_class.new(
          id: "outer_proc",
          procedures: [
            described_class.new(
              id: "inner_proc",
            ),
          ],
          functions: [
            Expressir::Model::Declarations::Function.new(
              id: "inner_func",
              return_type: Expressir::Model::DataTypes::Integer.new,
            ),
          ],
        )
      end

      it "handles local type declarations" do
        expect(procedure_with_locals.types.first.id).to eq "local_type"
        expect(procedure_with_locals.types.first.underlying_type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles local entity declarations" do
        expect(procedure_with_locals.entities.first.id).to eq "local_entity"
      end

      it "handles local constant declarations" do
        const = procedure_with_locals.constants.first
        expect(const.id).to eq "local_const"
        expect(const.expression.value).to eq "42"
      end

      it "handles local variable declarations" do
        var = procedure_with_locals.variables.first
        expect(var.id).to eq "local_var"
        expect(var.type).to be_a Expressir::Model::DataTypes::String
      end

      it "handles nested procedures and functions" do
        expect(nested_procedures.procedures.first.id).to eq "inner_proc"
        expect(nested_procedures.functions.first.id).to eq "inner_func"
      end
    end
  end

  describe "statement handling" do
    context "with different statement types" do
      let(:procedure_with_statements) do
        described_class.new(
          id: "proc_with_statements",
          variables: [
            Expressir::Model::Declarations::Variable.new(
              id: "test_var",
              type: Expressir::Model::DataTypes::Integer.new,
            ),
          ],
          statements: [
            Expressir::Model::Statements::Assignment.new(
              ref: Expressir::Model::References::SimpleReference.new(id: "test_var"),
              expression: Expressir::Model::Literals::Integer.new(value: "42"),
            ),
            Expressir::Model::Statements::If.new(
              expression: Expressir::Model::Literals::Logical.new(value: "TRUE"),
              statements: [
                Expressir::Model::Statements::Skip.new,
              ],
              else_statements: [
                Expressir::Model::Statements::Null.new,
              ],
            ),
            Expressir::Model::Statements::Repeat.new(
              statements: [
                Expressir::Model::Statements::Assignment.new(
                  ref: Expressir::Model::References::SimpleReference.new(id: "test_var"),
                  expression: Expressir::Model::Literals::Integer.new(value: "0"),
                ),
              ],
              while_expression: Expressir::Model::Literals::Logical.new(value: "FALSE"),
            ),
          ],
        )
      end

      it "handles assignment statements" do
        assignment = procedure_with_statements.statements[0]
        expect(assignment).to be_a Expressir::Model::Statements::Assignment
        expect(assignment.ref.id).to eq "test_var"
        expect(assignment.expression.value).to eq "42"
      end

      it "handles conditional statements" do
        if_stmt = procedure_with_statements.statements[1]
        expect(if_stmt).to be_a Expressir::Model::Statements::If
        expect(if_stmt.expression.value).to eq "TRUE"
        expect(if_stmt.statements.first).to be_a Expressir::Model::Statements::Skip
        expect(if_stmt.else_statements.first).to be_a Expressir::Model::Statements::Null
      end

      it "handles loop statements" do
        repeat_stmt = procedure_with_statements.statements[2]
        expect(repeat_stmt).to be_a Expressir::Model::Statements::Repeat
        expect(repeat_stmt.statements.first).to be_a Expressir::Model::Statements::Assignment
        expect(repeat_stmt.while_expression.value).to eq "FALSE"
      end
    end
  end

  describe "edge cases" do
    context "with unusual configurations" do
      let(:empty_procedure) do
        described_class.new(
          id: "empty_proc",
        )
      end

      let(:only_remarks_procedure) do
        described_class.new(
          id: "remarks_proc",
          remarks: ["Remark 1", "Remark 2"],
          remark_items: [
            Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
            Expressir::Model::Declarations::RemarkItem.new(id: "remark2"),
          ],
        )
      end

      let(:deep_nesting_procedure) do
        described_class.new(
          id: "deep_nested_proc",
          procedures: [
            described_class.new(
              id: "level1",
              procedures: [
                described_class.new(
                  id: "level2",
                ),
              ],
            ),
          ],
        )
      end

      it "handles empty procedures" do
        expect(empty_procedure.parameters).to eq([])
        expect(empty_procedure.statements).to eq([])
      end

      it "handles procedures with only remarks" do
        expect(only_remarks_procedure.remarks).to eq ["Remark 1", "Remark 2"]
        expect(only_remarks_procedure.remark_items.map(&:id)).to eq ["remark1",
                                                                     "remark2"]
      end

      it "handles deeply nested procedures" do
        level1 = deep_nesting_procedure.procedures.first
        level2 = level1.procedures.first
        expect(level1.id).to eq "level1"
        expect(level2.id).to eq "level2"
      end
    end
  end

  describe "#children" do
    let(:procedure) do
      described_class.new(
        id: "test_proc",
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
        procedures: [
          described_class.new(id: "proc1"),
        ],
        functions: [
          Expressir::Model::Declarations::Function.new(id: "func1"),
        ],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
        ],
      )
    end

    it "returns all child elements" do
      children_ids = procedure.children.map(&:id)
      expect(children_ids).to contain_exactly(
        "param1", "type1", "entity1", "const1", "var1",
        "proc1", "func1", "remark1"
      )
    end

    context "with empty procedure" do
      let(:empty_procedure) do
        described_class.new(id: "empty_proc")
      end

      it "returns empty array for procedure without children" do
        expect(empty_procedure.children).to be_empty
      end
    end
  end
end
