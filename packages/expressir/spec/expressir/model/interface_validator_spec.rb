# frozen_string_literal: true

require "spec_helper"
require "expressir/model/interface_validator"
require "expressir/model/repository"

RSpec.describe Expressir::Model::InterfaceValidator do
  # Helper to create a simple reference with an id
  def create_ref(id)
    ref = Expressir::Model::References::SimpleReference.new
    ref.instance_variable_set(:@id, id)
    def ref.id
      @id
    end
    ref
  end

  # Helper to create a test schema
  def create_schema(id:, entities: [], types: [], functions: [],
procedures: [], constants: [], rules: [], interfaces: [])
    schema = Expressir::Model::Declarations::Schema.new(id: id)
    schema.entities = entities.map { |e| Expressir::Model::Declarations::Entity.new(id: e).tap { |entity| entity.parent = schema } }
    schema.types = types.map { |t| Expressir::Model::Declarations::Type.new(id: t).tap { |type| type.parent = schema } }
    schema.functions = functions.map { |f| Expressir::Model::Declarations::Function.new(id: f).tap { |func| func.parent = schema } }
    schema.procedures = procedures.map { |p| Expressir::Model::Declarations::Procedure.new(id: p).tap { |proc| proc.parent = schema } }
    schema.constants = constants.map { |c| Expressir::Model::Declarations::Constant.new(id: c).tap { |const| const.parent = schema } }
    schema.rules = rules.map { |r| Expressir::Model::Declarations::Rule.new(id: r).tap { |rule| rule.parent = schema } }
    schema.interfaces = interfaces
    schema
  end

  # Helper to create a USE FROM interface
  def create_use_from(schema_name, items = [])
    interface = Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
    )
    interface.schema = create_ref(schema_name)
    interface.items = items.map do |item_name, alias_name|
      item = Expressir::Model::Declarations::InterfaceItem.new
      item.ref = create_ref(item_name)
      item.id = alias_name if alias_name
      item
    end
    interface
  end

  # Helper to create a REFERENCE FROM interface
  def create_reference_from(schema_name, items = [])
    interface = Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::REFERENCE,
    )
    interface.schema = create_ref(schema_name)
    interface.items = items.map do |item_name, alias_name|
      item = Expressir::Model::Declarations::InterfaceItem.new
      item.ref = create_ref(item_name)
      item.id = alias_name if alias_name
      item
    end
    interface
  end

  let(:repo) do
    repo = Expressir::Model::Repository.new

    # Schema 1: base_schema with entities and types
    schema1 = create_schema(
      id: "base_schema",
      entities: ["person", "organization", "address"],
      types: ["identifier", "label", "text"],
      functions: ["validate_id"],
      constants: ["MAX_LENGTH"],
    )
    repo.add_schema(schema1)

    # Schema 2: extended_schema that uses base_schema
    use_interface = create_use_from("base_schema",
                                    [["person", nil], ["identifier", nil]])
    schema2 = create_schema(
      id: "extended_schema",
      entities: ["employee", "department"],
      interfaces: [use_interface],
    )
    repo.add_schema(schema2)

    # Schema 3: reference_schema that references base_schema
    ref_interface = create_reference_from("base_schema",
                                          [["organization", nil]])
    schema3 = create_schema(
      id: "reference_schema",
      entities: ["company"],
      interfaces: [ref_interface],
    )
    repo.add_schema(schema3)

    repo.build_indexes
    repo
  end

  let(:validator) { described_class.new(repo) }

  describe "#initialize" do
    it "initializes with a repository" do
      expect(validator.repository).to eq(repo)
    end

    it "stores schemas from repository" do
      expect(validator.schemas).to eq(repo.schemas)
    end
  end

  describe "#validate" do
    context "with valid interfaces" do
      it "returns valid result" do
        result = validator.validate
        expect(result[:valid?]).to be true
      end

      it "returns empty errors array" do
        result = validator.validate
        expect(result[:errors]).to be_empty
      end

      it "includes statistics" do
        result = validator.validate
        expect(result[:stats]).to include(:use_from, :reference_from,
                                          :total_items)
      end

      it "counts USE FROM statements correctly" do
        result = validator.validate
        expect(result[:stats][:use_from]).to eq(1)
      end

      it "counts REFERENCE FROM statements correctly" do
        result = validator.validate
        expect(result[:stats][:reference_from]).to eq(1)
      end

      it "counts total interface items correctly" do
        result = validator.validate
        expect(result[:stats][:total_items]).to eq(3)
      end
    end

    context "with missing schema reference" do
      let(:invalid_repo) do
        repo = Expressir::Model::Repository.new
        use_interface = create_use_from("non_existent_schema", [["item1", nil]])
        schema = create_schema(id: "test_schema", interfaces: [use_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:invalid_validator) { described_class.new(invalid_repo) }

      it "returns invalid result" do
        result = invalid_validator.validate
        expect(result[:valid?]).to be false
      end

      it "includes missing schema error" do
        result = invalid_validator.validate
        expect(result[:errors]).not_to be_empty
        error = result[:errors].first
        expect(error[:type]).to eq(:missing_schema_reference)
      end

      it "includes schema name in error" do
        result = invalid_validator.validate
        error = result[:errors].first
        expect(error[:schema]).to eq("test_schema")
      end

      it "includes referenced schema name in error" do
        result = invalid_validator.validate
        error = result[:errors].first
        expect(error[:referenced_schema]).to eq("non_existent_schema")
      end

      it "includes fix suggestion" do
        result = invalid_validator.validate
        error = result[:errors].first
        expect(error[:fix_suggestion]).to include("Ensure schema")
      end
    end

    context "with missing interface item" do
      let(:invalid_repo) do
        repo = Expressir::Model::Repository.new
        base = create_schema(id: "base", entities: ["entity1"])
        repo.add_schema(base)

        use_interface = create_use_from("base",
                                        [["entity1", nil],
                                         ["non_existent", nil]])
        schema = create_schema(id: "test_schema", interfaces: [use_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:invalid_validator) { described_class.new(invalid_repo) }

      it "returns invalid result" do
        result = invalid_validator.validate
        expect(result[:valid?]).to be false
      end

      it "includes missing item error" do
        result = invalid_validator.validate
        expect(result[:errors]).not_to be_empty
        error = result[:errors].first
        expect(error[:type]).to eq(:missing_interface_item)
      end

      it "includes item name in error" do
        result = invalid_validator.validate
        error = result[:errors].first
        expect(error[:item]).to eq("non_existent")
      end

      it "includes available items in fix suggestion" do
        result = invalid_validator.validate
        error = result[:errors].first
        expect(error[:fix_suggestion]).to include("Available items")
      end
    end

    context "with empty USE FROM items" do
      let(:empty_use_repo) do
        repo = Expressir::Model::Repository.new
        base = create_schema(id: "base", entities: ["entity1"])
        repo.add_schema(base)

        use_interface = create_use_from("base", [])
        schema = create_schema(id: "test_schema", interfaces: [use_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:empty_use_validator) { described_class.new(empty_use_repo) }

      it "returns valid result (empty USE FROM is valid)" do
        result = empty_use_validator.validate
        expect(result[:valid?]).to be true
      end

      it "includes warning about empty items" do
        result = empty_use_validator.validate
        expect(result[:warnings]).not_to be_empty
        warning = result[:warnings].first
        expect(warning[:type]).to eq(:empty_interface_items)
      end

      it "suggests explicit item list" do
        result = empty_use_validator.validate
        warning = result[:warnings].first
        expect(warning[:fix_suggestion]).to include("Add explicit item list")
      end
    end

    context "with empty REFERENCE FROM items" do
      let(:empty_ref_repo) do
        repo = Expressir::Model::Repository.new
        base = create_schema(id: "base", entities: ["entity1"])
        repo.add_schema(base)

        ref_interface = create_reference_from("base", [])
        schema = create_schema(id: "test_schema", interfaces: [ref_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:empty_ref_validator) { described_class.new(empty_ref_repo) }

      it "returns invalid result (empty REFERENCE FROM is invalid)" do
        result = empty_ref_validator.validate
        expect(result[:valid?]).to be false
      end

      it "includes error for empty REFERENCE FROM" do
        result = empty_ref_validator.validate
        expect(result[:errors]).not_to be_empty
        error = result[:errors].first
        expect(error[:type]).to eq(:empty_interface_items)
      end

      it "includes fix suggestion" do
        result = empty_ref_validator.validate
        error = result[:errors].first
        expect(error[:fix_suggestion]).to include("Add item list")
      end
    end

    context "with detailed option" do
      it "includes interface report" do
        result = validator.validate(detailed: true)
        expect(result[:interface_report]).not_to be_nil
      end

      it "includes statistics in report" do
        result = validator.validate(detailed: true)
        expect(result[:interface_report]).to include("Statistics:")
        expect(result[:interface_report]).to include("Total USE FROM statements:")
      end

      it "includes errors section in report" do
        result = validator.validate(detailed: true)
        # Should include either "Errors" or "No errors found"
        expect(result[:interface_report]).to match(/Errors|No errors/)
      end

      it "includes warnings section in report" do
        result = validator.validate(detailed: true)
        # Should include either "Warnings" or "No warnings"
        expect(result[:interface_report]).to match(/Warnings|No warnings/)
      end

      it "formats report with separators" do
        result = validator.validate(detailed: true)
        expect(result[:interface_report]).to include("=" * 80)
      end
    end

    context "with check_duplicates option" do
      let(:duplicate_repo) do
        repo = Expressir::Model::Repository.new
        base = create_schema(id: "base", entities: ["entity1", "entity2"])
        repo.add_schema(base)

        use_interface = create_use_from("base",
                                        [["entity1", "item"],
                                         ["entity2", "item"]])
        schema = create_schema(id: "test_schema", interfaces: [use_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:duplicate_validator) { described_class.new(duplicate_repo) }

      it "detects duplicate aliases" do
        result = duplicate_validator.validate(check_duplicates: true)
        expect(result[:valid?]).to be false
      end

      it "includes duplicate alias error" do
        result = duplicate_validator.validate(check_duplicates: true)
        error = result[:errors].first
        expect(error[:type]).to eq(:duplicate_interface_alias)
      end

      it "includes alias name in error" do
        result = duplicate_validator.validate(check_duplicates: true)
        error = result[:errors].first
        expect(error[:alias]).to eq("item")
      end

      it "does not check duplicates when option is false" do
        result = duplicate_validator.validate(check_duplicates: false)
        expect(result[:valid?]).to be true
      end
    end

    context "with check_self_references option" do
      let(:self_ref_repo) do
        repo = Expressir::Model::Repository.new
        # Create a base schema to reference
        base = create_schema(id: "other_schema", entities: ["entity1"])
        repo.add_schema(base)

        # Create a schema that references itself (with items to avoid empty warning)
        use_interface = create_use_from("test_schema", [["entity1", nil]])
        schema = create_schema(id: "test_schema", entities: ["entity1"],
                               interfaces: [use_interface])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:self_ref_validator) { described_class.new(self_ref_repo) }

      it "detects self-references" do
        result = self_ref_validator.validate(check_self_references: true)
        expect(result[:warnings]).not_to be_empty
      end

      it "includes self-reference warning" do
        result = self_ref_validator.validate(check_self_references: true)
        warning = result[:warnings].find do |w|
          w[:type] == :self_reference_interface
        end
        expect(warning).not_to be_nil
      end

      it "suggests removing self-reference" do
        result = self_ref_validator.validate(check_self_references: true)
        warning = result[:warnings].find do |w|
          w[:type] == :self_reference_interface
        end
        expect(warning[:fix_suggestion]).to include("Remove self-referencing")
      end

      it "does not check self-references when option is false" do
        result = self_ref_validator.validate(check_self_references: false)
        # Should not have self-reference warnings
        self_ref_warnings = result[:warnings].select do |w|
          w[:type] == :self_reference_interface
        end
        expect(self_ref_warnings).to be_empty
      end
    end

    context "with multiple validation issues" do
      let(:complex_repo) do
        repo = Expressir::Model::Repository.new
        base = create_schema(id: "base", entities: ["entity1"])
        repo.add_schema(base)

        use_interface1 = create_use_from("base",
                                         [["entity1", nil],
                                          ["missing_item", nil]])
        use_interface2 = create_use_from("non_existent", [])
        schema = create_schema(id: "test_schema",
                               interfaces: [
                                 use_interface1, use_interface2
                               ])
        repo.add_schema(schema)
        repo.build_indexes
        repo
      end

      let(:complex_validator) { described_class.new(complex_repo) }

      it "reports all errors" do
        result = complex_validator.validate
        expect(result[:errors].size).to be >= 2
      end

      it "includes both missing schema and missing item errors" do
        result = complex_validator.validate
        error_types = result[:errors].map { |e| e[:type] }
        expect(error_types).to include(:missing_schema_reference,
                                       :missing_interface_item)
      end
    end
  end

  describe "#validate_schema" do
    it "validates a specific schema by name" do
      result = validator.validate_schema("extended_schema")
      expect(result[:valid?]).to be true
    end

    it "returns error for non-existent schema" do
      result = validator.validate_schema("non_existent")
      expect(result[:valid?]).to be false
      expect(result[:errors].first[:type]).to eq(:schema_not_found)
    end

    it "includes statistics for the schema" do
      result = validator.validate_schema("extended_schema")
      expect(result[:stats]).to include(:use_from, :reference_from,
                                        :total_items)
    end

    it "validates only the specified schema" do
      result = validator.validate_schema("extended_schema")
      expect(result[:stats][:use_from]).to eq(1)
      expect(result[:stats][:reference_from]).to eq(0)
    end
  end

  describe "case insensitive matching" do
    let(:case_repo) do
      repo = Expressir::Model::Repository.new
      base = create_schema(id: "BASE_SCHEMA", entities: ["MyEntity"])
      repo.add_schema(base)

      use_interface = create_use_from("base_schema", [["myentity", nil]])
      schema = create_schema(id: "test_schema", interfaces: [use_interface])
      repo.add_schema(schema)
      repo.build_indexes
      repo
    end

    let(:case_validator) { described_class.new(case_repo) }

    it "matches schema names case-insensitively" do
      result = case_validator.validate
      expect(result[:valid?]).to be true
    end

    it "matches item names case-insensitively" do
      result = case_validator.validate
      expect(result[:valid?]).to be true
    end
  end

  describe "validation with different item types" do
    let(:multi_type_repo) do
      repo = Expressir::Model::Repository.new
      base = create_schema(
        id: "base",
        entities: ["my_entity"],
        types: ["my_type"],
        functions: ["my_function"],
        procedures: ["my_procedure"],
        constants: ["MY_CONSTANT"],
        rules: ["my_rule"],
      )
      repo.add_schema(base)

      use_interface = create_use_from("base", [
                                        ["my_entity", nil],
                                        ["my_type", nil],
                                        ["my_function", nil],
                                        ["my_procedure", nil],
                                        ["MY_CONSTANT", nil],
                                        ["my_rule", nil],
                                      ])
      schema = create_schema(id: "test_schema", interfaces: [use_interface])
      repo.add_schema(schema)
      repo.build_indexes
      repo
    end

    let(:multi_type_validator) { described_class.new(multi_type_repo) }

    it "validates entities" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "validates types" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "validates functions" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "validates procedures" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "validates constants" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "validates rules" do
      result = multi_type_validator.validate
      expect(result[:valid?]).to be true
    end

    it "counts all items correctly" do
      result = multi_type_validator.validate
      expect(result[:stats][:total_items]).to eq(6)
    end
  end

  describe "error message quality" do
    let(:error_repo) do
      repo = Expressir::Model::Repository.new
      use_interface = create_use_from("missing", [])
      schema = create_schema(id: "test", interfaces: [use_interface])
      repo.add_schema(schema)
      repo.build_indexes
      repo
    end

    let(:error_validator) { described_class.new(error_repo) }

    it "provides clear error messages" do
      result = error_validator.validate
      error = result[:errors].first
      expect(error[:message]).to be_a(String)
      expect(error[:message].length).to be > 10
    end

    it "provides actionable fix suggestions" do
      result = error_validator.validate
      error = result[:errors].first
      expect(error[:fix_suggestion]).to be_a(String)
      expect(error[:fix_suggestion]).not_to be_empty
    end
  end

  describe "detailed report format" do
    it "creates a readable report" do
      result = validator.validate(detailed: true)
      report = result[:interface_report]
      expect(report).to include("Interface Validation Report")
    end

    it "includes visual separators" do
      result = validator.validate(detailed: true)
      report = result[:interface_report]
      expect(report.scan(/={80}/).size).to be >= 2
    end

    it "shows success message when no errors" do
      result = validator.validate(detailed: true)
      report = result[:interface_report]
      expect(report).to include("✓ No errors found")
    end

    it "shows numbered error list when errors exist" do
      invalid_repo = Expressir::Model::Repository.new
      use_interface = create_use_from("missing", [])
      schema = create_schema(id: "test", interfaces: [use_interface])
      invalid_repo.add_schema(schema)
      invalid_repo.build_indexes
      invalid_validator = described_class.new(invalid_repo)

      result = invalid_validator.validate(detailed: true)
      report = result[:interface_report]
      expect(report).to match(/1\. \[.*\]/)
    end
  end
end
