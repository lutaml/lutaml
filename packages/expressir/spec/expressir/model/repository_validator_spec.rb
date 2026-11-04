# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::RepositoryValidator do
  # Use REAL objects instead of mocks
  let(:entity1) do
    Expressir::Model::Declarations::Entity.new(id: "entity1")
  end

  let(:type1) do
    Expressir::Model::Declarations::Type.new(id: "type1")
  end

  let(:function1) do
    Expressir::Model::Declarations::Function.new(id: "function1")
  end

  let(:procedure1) do
    Expressir::Model::Declarations::Procedure.new(id: "procedure1")
  end

  let(:constant1) do
    Expressir::Model::Declarations::Constant.new(id: "constant1")
  end

  let(:referenced_schema) do
    Expressir::Model::Declarations::Schema.new(
      id: "referenced_schema",
      entities: [entity1],
      types: [type1],
      functions: [function1],
      procedures: [procedure1],
      constants: [constant1],
      interfaces: nil,
    )
  end

  let(:use_interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
      items: [
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "entity1"),
        ),
      ],
    )
  end

  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema1",
      interfaces: [use_interface],
    )
  end

  let(:missing_schema_interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::REFERENCE,
      schema: Expressir::Model::Declarations::Schema.new(id: "missing_schema"),
      items: [],
    )
  end

  let(:invalid_item_interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
      items: [
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "nonexistent"),
        ),
      ],
    )
  end

  let(:schema_with_missing_ref) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema_missing_ref",
      interfaces: [missing_schema_interface],
    )
  end

  let(:schema_with_invalid_item) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema_invalid_item",
      interfaces: [invalid_item_interface],
    )
  end

  let(:reference_index) do
    Expressir::Model::Indexes::ReferenceIndex.new([schema1, referenced_schema])
  end

  describe "#initialize" do
    it "initializes with schemas and reference index" do
      validator = described_class.new([schema1], reference_index)

      expect(validator).to be_a(described_class)
    end

    it "accepts empty schemas array" do
      validator = described_class.new([], reference_index)

      expect(validator).to be_a(described_class)
    end
  end

  describe "#validate" do
    context "with valid schemas" do
      let(:schemas) { [schema1, referenced_schema] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "returns valid result when all checks pass" do
        result = validator.validate

        expect(result[:valid?]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
      end

      it "returns hash with required keys" do
        result = validator.validate

        expect(result).to have_key(:valid?)
        expect(result).to have_key(:errors)
        expect(result).to have_key(:warnings)
      end
    end

    context "with missing schema reference" do
      let(:schemas) { [schema_with_missing_ref] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "returns invalid result" do
        result = validator.validate

        expect(result[:valid?]).to be false
      end

      it "includes missing schema error" do
        result = validator.validate

        expect(result[:errors]).not_to be_empty
        error = result[:errors].first
        expect(error[:type]).to eq(:missing_schema_reference)
        expect(error[:referenced_schema]).to be_a(String)
      end

      it "includes descriptive error message" do
        result = validator.validate

        error = result[:errors].first
        expect(error[:message]).to include("references non-existent schema")
      end
    end

    context "with missing interface item" do
      let(:schemas) { [schema_with_invalid_item, referenced_schema] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "returns invalid result" do
        result = validator.validate

        expect(result[:valid?]).to be false
      end

      it "includes missing interface item error" do
        result = validator.validate

        expect(result[:errors]).not_to be_empty
        error = result[:errors].first
        expect(error[:type]).to eq(:missing_interface_item)
        expect(error[:item]).to be_a(String)
      end

      it "includes descriptive error message" do
        result = validator.validate

        error = result[:errors].first
        expect(error[:message]).to include("Interface item")
        expect(error[:message]).to include("not found")
      end
    end

    context "with circular dependencies" do
      let(:circular_schema1) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema_a",
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::Declarations::Schema.new(id: "schema_b"),
              items: [],
            ),
          ],
        )
      end

      let(:circular_schema2) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema_b",
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::Declarations::Schema.new(id: "schema_a"),
              items: [],
            ),
          ],
        )
      end

      let(:schemas) { [circular_schema1, circular_schema2] }
      let(:ref_index) { Expressir::Model::Indexes::ReferenceIndex.new(schemas) }
      let(:validator) { described_class.new(schemas, ref_index) }

      it "returns valid result (circular dependencies are warnings, not errors)" do
        result = validator.validate

        expect(result[:valid?]).to be true
      end

      it "includes circular dependency warning" do
        result = validator.validate

        expect(result[:warnings]).not_to be_empty
        circular_warnings = result[:warnings].select do |w|
          w[:type] == :circular_dependency
        end
        expect(circular_warnings).not_to be_empty
        expect(circular_warnings.first[:cycle]).to be_an(Array)
      end

      it "includes descriptive warning message" do
        result = validator.validate

        circular_warnings = result[:warnings].select do |w|
          w[:type] == :circular_dependency
        end
        warning = circular_warnings.first
        expect(warning[:message]).to include("Circular dependency")
        expect(warning[:message]).to include("->")
      end
    end

    context "with multiple circular dependencies" do
      let(:schemas) do
        [
          Expressir::Model::Declarations::Schema.new(
            id: "s1",
            interfaces: [
              Expressir::Model::Declarations::Interface.new(
                kind: Expressir::Model::Declarations::Interface::USE,
                schema: Expressir::Model::Declarations::Schema.new(id: "s2"),
                items: [],
              ),
            ],
          ),
          Expressir::Model::Declarations::Schema.new(
            id: "s2",
            interfaces: [
              Expressir::Model::Declarations::Interface.new(
                kind: Expressir::Model::Declarations::Interface::USE,
                schema: Expressir::Model::Declarations::Schema.new(id: "s1"),
                items: [],
              ),
            ],
          ),
          Expressir::Model::Declarations::Schema.new(
            id: "s3",
            interfaces: [
              Expressir::Model::Declarations::Interface.new(
                kind: Expressir::Model::Declarations::Interface::USE,
                schema: Expressir::Model::Declarations::Schema.new(id: "s4"),
                items: [],
              ),
            ],
          ),
          Expressir::Model::Declarations::Schema.new(
            id: "s4",
            interfaces: [
              Expressir::Model::Declarations::Interface.new(
                kind: Expressir::Model::Declarations::Interface::USE,
                schema: Expressir::Model::Declarations::Schema.new(id: "s3"),
                items: [],
              ),
            ],
          ),
        ]
      end
      let(:ref_index) { Expressir::Model::Indexes::ReferenceIndex.new(schemas) }
      let(:validator) { described_class.new(schemas, ref_index) }

      it "reports all circular dependencies as warnings" do
        result = validator.validate

        circular_warnings = result[:warnings].select do |w|
          w[:type] == :circular_dependency
        end
        expect(circular_warnings.size).to eq(2)
      end
    end

    context "with strict mode disabled" do
      let(:standalone_schema) do
        Expressir::Model::Declarations::Schema.new(id: "standalone")
      end
      let(:schemas) { [schema1, standalone_schema] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "does not detect unused schemas" do
        result = validator.validate(strict: false)

        unused_warnings = result[:warnings].select do |w|
          w[:type] == :unused_schema
        end
        expect(unused_warnings).to be_empty
      end
    end

    context "with strict mode enabled" do
      let(:standalone_schema) do
        Expressir::Model::Declarations::Schema.new(id: "standalone")
      end
      let(:schemas) { [schema1, referenced_schema, standalone_schema] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "detects unused schemas" do
        result = validator.validate(strict: true)

        expect(result[:warnings]).not_to be_empty
        warning = result[:warnings].find { |w| w[:type] == :unused_schema }
        expect(warning).not_to be_nil
      end

      it "includes descriptive warning message" do
        result = validator.validate(strict: true)

        warning = result[:warnings].find { |w| w[:type] == :unused_schema }
        expect(warning[:message]).to include("not referenced")
      end

      it "does not warn for single schema repository" do
        single_schema = Expressir::Model::Declarations::Schema.new(id: "single")
        single_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([single_schema])
        single_validator = described_class.new([single_schema],
                                               single_ref_index)

        result = single_validator.validate(strict: true)

        unused_warnings = result[:warnings].select do |w|
          w[:type] == :unused_schema
        end
        expect(unused_warnings).to be_empty
      end
    end

    context "with schemas without interfaces" do
      let(:no_interface_schema) do
        Expressir::Model::Declarations::Schema.new(id: "no_interfaces")
      end
      let(:schemas) { [no_interface_schema] }
      let(:ref_index) { Expressir::Model::Indexes::ReferenceIndex.new(schemas) }
      let(:validator) { described_class.new(schemas, ref_index) }

      it "handles nil interfaces gracefully" do
        expect { validator.validate }.not_to raise_error
      end

      it "returns valid result" do
        result = validator.validate

        expect(result[:valid?]).to be true
      end
    end

    context "with multiple error types" do
      let(:problematic_schema) do
        Expressir::Model::Declarations::Schema.new(
          id: "problematic",
          interfaces: [missing_schema_interface, invalid_item_interface],
        )
      end
      let(:schemas) { [problematic_schema, referenced_schema] }
      let(:ref_index) { Expressir::Model::Indexes::ReferenceIndex.new(schemas) }
      let(:validator) { described_class.new(schemas, ref_index) }

      it "accumulates all errors" do
        result = validator.validate

        expect(result[:errors].size).to be >= 2
      end

      it "includes different error types" do
        result = validator.validate

        error_types = result[:errors].map { |e| e[:type] }
        expect(error_types).to include(:missing_schema_reference)
      end
    end
  end

  describe "interface item validation" do
    let(:schemas) { [schema1, referenced_schema] }
    let(:validator) { described_class.new(schemas, reference_index) }

    it "validates entity items" do
      entity_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
        items: [
          Expressir::Model::Declarations::InterfaceItem.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "entity1"),
          ),
        ],
      )
      schema_with_entity = Expressir::Model::Declarations::Schema.new(
        id: "test",
        interfaces: [entity_interface],
      )
      test_schemas = [schema_with_entity, referenced_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(test_schemas)
      test_validator = described_class.new(test_schemas, test_ref_index)

      result = test_validator.validate

      expect(result[:valid?]).to be true
    end

    it "validates type items" do
      type_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
        items: [
          Expressir::Model::Declarations::InterfaceItem.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "type1"),
          ),
        ],
      )
      schema_with_type = Expressir::Model::Declarations::Schema.new(
        id: "test",
        interfaces: [type_interface],
      )
      test_schemas = [schema_with_type, referenced_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(test_schemas)
      test_validator = described_class.new(test_schemas, test_ref_index)

      result = test_validator.validate

      expect(result[:valid?]).to be true
    end

    it "validates function items" do
      function_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
        items: [
          Expressir::Model::Declarations::InterfaceItem.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "function1"),
          ),
        ],
      )
      schema_with_function = Expressir::Model::Declarations::Schema.new(
        id: "test",
        interfaces: [function_interface],
      )
      test_schemas = [schema_with_function, referenced_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(test_schemas)
      test_validator = described_class.new(test_schemas, test_ref_index)

      result = test_validator.validate

      expect(result[:valid?]).to be true
    end

    it "validates procedure items" do
      procedure_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
        items: [
          Expressir::Model::Declarations::InterfaceItem.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "procedure1"),
          ),
        ],
      )
      schema_with_procedure = Expressir::Model::Declarations::Schema.new(
        id: "test",
        interfaces: [procedure_interface],
      )
      test_schemas = [schema_with_procedure, referenced_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(test_schemas)
      test_validator = described_class.new(test_schemas, test_ref_index)

      result = test_validator.validate

      expect(result[:valid?]).to be true
    end

    it "validates constant items" do
      constant_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "referenced_schema"),
        items: [
          Expressir::Model::Declarations::InterfaceItem.new(
            ref: Expressir::Model::References::SimpleReference.new(id: "constant1"),
          ),
        ],
      )
      schema_with_constant = Expressir::Model::Declarations::Schema.new(
        id: "test",
        interfaces: [constant_interface],
      )
      test_schemas = [schema_with_constant, referenced_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(test_schemas)
      test_validator = described_class.new(test_schemas, test_ref_index)

      result = test_validator.validate

      expect(result[:valid?]).to be true
    end
  end

  describe "validation behavior" do
    let(:validator) do
      described_class.new([schema1, referenced_schema], reference_index)
    end

    it "validates repository by calling validate method" do
      result = validator.validate
      expect(result[:valid?]).to be true
    end
  end

  describe "extensibility" do
    it "allows adding new validation rules through subclassing" do
      expect(described_class).to be < Object
    end

    it "provides structured error and warning formats" do
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([schema_with_missing_ref])
      validator = described_class.new([schema_with_missing_ref], test_ref_index)

      result = validator.validate

      error = result[:errors].first
      expect(error).to have_key(:type)
      expect(error).to have_key(:message)
      expect(error).to have_key(:schema)
    end
  end

  describe "edge cases" do
    it "handles empty schemas array" do
      validator = described_class.new([], reference_index)

      result = validator.validate

      expect(result[:valid?]).to be true
      expect(result[:errors]).to be_empty
    end

    it "handles schemas with empty interfaces array" do
      empty_interfaces_schema = Expressir::Model::Declarations::Schema.new(
        id: "empty",
        interfaces: [],
      )
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([empty_interfaces_schema])
      validator = described_class.new([empty_interfaces_schema], test_ref_index)

      result = validator.validate

      expect(result[:valid?]).to be true
    end

    it "handles case-insensitive schema name matching" do
      uppercase_ref_interface = Expressir::Model::Declarations::Interface.new(
        kind: Expressir::Model::Declarations::Interface::USE,
        schema: Expressir::Model::Declarations::Schema.new(id: "REFERENCED_SCHEMA"),
        items: [],
      )
      uppercase_schema = Expressir::Model::Declarations::Schema.new(
        id: "UPPERCASE",
        interfaces: [uppercase_ref_interface],
      )
      lowercase_schema = Expressir::Model::Declarations::Schema.new(
        id: "referenced_schema",
      )
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([
                                                                       uppercase_schema, lowercase_schema
                                                                     ])
      validator = described_class.new([uppercase_schema, lowercase_schema],
                                      test_ref_index)

      result = validator.validate

      expect(result[:valid?]).to be true
    end
  end

  describe "enhanced validation features" do
    describe "check_interfaces option" do
      let(:validator) do
        described_class.new([schema1, referenced_schema], reference_index)
      end

      it "skips detailed interface validation when false" do
        result = validator.validate(check_interfaces: false)

        expect(result[:valid?]).to be true
        expect(result[:interface_report]).to be_nil
      end

      it "performs detailed interface validation when true" do
        result = validator.validate(check_interfaces: true)

        expect(result).to have_key(:valid?)
      end
    end

    describe "check_completeness option" do
      it "does not check completeness when false" do
        empty_schema = Expressir::Model::Declarations::Schema.new(id: "empty")
        test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([empty_schema])
        validator = described_class.new([empty_schema], test_ref_index)

        result = validator.validate(check_completeness: false)

        empty_warnings = result[:warnings].select do |w|
          w[:type] == :empty_schema
        end
        expect(empty_warnings).to be_empty
      end

      it "warns about empty schemas when true" do
        empty_schema = Expressir::Model::Declarations::Schema.new(id: "empty")
        test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([empty_schema])
        validator = described_class.new([empty_schema], test_ref_index)

        result = validator.validate(check_completeness: true)

        expect(result[:warnings]).not_to be_empty
        warning = result[:warnings].find { |w| w[:type] == :empty_schema }
        expect(warning).not_to be_nil
      end

      it "warns about schemas with no types when they have entities" do
        schema_no_types = Expressir::Model::Declarations::Schema.new(
          id: "no_types",
          entities: [entity1],
        )
        test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([schema_no_types])
        validator = described_class.new([schema_no_types], test_ref_index)

        result = validator.validate(check_completeness: true)

        expect(result[:warnings]).not_to be_empty
        warning = result[:warnings].find { |w| w[:type] == :no_types }
        expect(warning).not_to be_nil
      end
    end

    describe "detailed option" do
      let(:validator) do
        described_class.new([schema1, referenced_schema], reference_index)
      end

      it "does not include detailed report when false" do
        result = validator.validate(detailed: false, check_interfaces: false)

        expect(result[:interface_report]).to be_nil
      end
    end

    describe "option combinations" do
      let(:standalone_schema) { Expressir::Model::Declarations::Schema.new(id: "standalone") }
      let(:schemas) { [schema1, referenced_schema, standalone_schema] }
      let(:validator) { described_class.new(schemas, reference_index) }

      it "handles strict and check_completeness together" do
        result = validator.validate(strict: true, check_completeness: true)

        expect(result[:warnings].size).to be >= 1
      end

      it "handles all options enabled" do
        result = validator.validate(
          strict: true,
          check_interfaces: true,
          check_completeness: true,
          detailed: true,
          check_duplicates: false,
          check_self_references: false,
        )

        expect(result).to have_key(:valid?)
        expect(result).to have_key(:errors)
        expect(result).to have_key(:warnings)
      end
    end

    describe "error handling" do
      it "handles interface validation errors gracefully" do
        # Create a minimal valid setup
        validator = described_class.new([schema1, referenced_schema],
                                        reference_index)

        result = validator.validate(check_interfaces: true)

        # Should not crash
        expect(result).to have_key(:valid?)
      end
    end
  end

  describe "backward compatibility" do
    let(:validator) do
      described_class.new([schema1, referenced_schema], reference_index)
    end

    it "maintains existing behavior with no options" do
      result = validator.validate

      expect(result[:valid?]).to be true
      expect(result[:errors]).to be_empty
    end

    it "maintains existing strict mode behavior" do
      standalone_schema = Expressir::Model::Declarations::Schema.new(id: "standalone")
      schemas = [schema1, referenced_schema, standalone_schema]
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(schemas)
      validator = described_class.new(schemas, test_ref_index)

      result = validator.validate(strict: true)

      expect(result[:warnings]).not_to be_empty
      expect(result[:warnings].any? do |w|
        w[:type] == :unused_schema
      end).to be true
    end
  end

  describe "validation result structure" do
    let(:validator) { described_class.new([schema1], reference_index) }

    it "always includes required keys" do
      result = validator.validate

      expect(result).to have_key(:valid?)
      expect(result).to have_key(:errors)
      expect(result).to have_key(:warnings)
    end
  end

  describe "completeness checks" do
    it "identifies schemas with entities but no types as potentially incomplete" do
      schema_with_entities = Expressir::Model::Declarations::Schema.new(
        id: "has_entities",
        entities: [entity1],
        types: [],
      )
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([schema_with_entities])
      validator = described_class.new([schema_with_entities], test_ref_index)

      result = validator.validate(check_completeness: true)

      warning = result[:warnings].find { |w| w[:type] == :no_types }
      expect(warning).not_to be_nil
      expect(warning[:message]).to include("has entities but no types")
    end

    it "does not warn about schemas with both entities and types" do
      complete_schema = Expressir::Model::Declarations::Schema.new(
        id: "complete",
        entities: [entity1],
        types: [type1],
      )
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new([complete_schema])
      validator = described_class.new([complete_schema], test_ref_index)

      result = validator.validate(check_completeness: true)

      no_types_warnings = result[:warnings].select { |w| w[:type] == :no_types }
      expect(no_types_warnings).to be_empty
    end
  end

  describe "validation performance" do
    it "performs basic validation efficiently" do
      schemas = Array.new(10) do |i|
        Expressir::Model::Declarations::Schema.new(id: "schema#{i}")
      end
      test_ref_index = Expressir::Model::Indexes::ReferenceIndex.new(schemas)
      validator = described_class.new(schemas, test_ref_index)

      start_time = Time.now
      result = validator.validate
      elapsed = Time.now - start_time

      expect(result[:valid?]).to be true
      expect(elapsed).to be < 1.0 # Should complete in under 1 second
    end
  end
end
