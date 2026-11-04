# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Model::Repository do
  let(:schema1) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema_one",
      entities: [
        Expressir::Model::Declarations::Entity.new(id: "entity_a"),
        Expressir::Model::Declarations::Entity.new(id: "entity_b"),
      ],
      types: [
        Expressir::Model::Declarations::Type.new(
          id: "type_x",
          underlying_type: Expressir::Model::DataTypes::Select.new,
        ),
        Expressir::Model::Declarations::Type.new(
          id: "type_y",
          underlying_type: Expressir::Model::DataTypes::Enumeration.new(items: []),
        ),
      ],
      functions: [
        Expressir::Model::Declarations::Function.new(id: "func_1"),
      ],
      rules: [
        Expressir::Model::Declarations::Rule.new(id: "rule_1"),
      ],
      procedures: [
        Expressir::Model::Declarations::Procedure.new(id: "proc_1"),
      ],
      interfaces: [],
    )
  end

  let(:schema2) do
    Expressir::Model::Declarations::Schema.new(
      id: "schema_two",
      entities: [
        Expressir::Model::Declarations::Entity.new(id: "entity_c"),
      ],
      types: [
        Expressir::Model::Declarations::Type.new(
          id: "type_z",
          underlying_type: Expressir::Model::DataTypes::Array.new,
        ),
      ],
      interfaces: [
        Expressir::Model::Declarations::Interface.new(
          kind: Expressir::Model::Declarations::Interface::USE,
          schema: Expressir::Model::References::SimpleReference.new(id: "schema_one"),
          items: [
            Expressir::Model::Declarations::InterfaceItem.new(
              ref: Expressir::Model::References::SimpleReference.new(id: "entity_a"),
            ),
          ],
        ),
      ],
    )
  end

  let(:repository) do
    described_class.new(schemas: [schema1, schema2])
  end

  describe "#initialize" do
    it "creates a repository with schemas" do
      expect(repository.schemas).to contain_exactly(schema1, schema2)
    end

    it "initializes nil indexes (lazy-loaded)" do
      expect(repository.entity_index).to be_nil
      expect(repository.type_index).to be_nil
      expect(repository.reference_index).to be_nil
    end

    it "accepts a base_dir parameter" do
      repo = described_class.new(base_dir: "/tmp/test")
      expect(repo.base_dir).to eq("/tmp/test")
    end
  end

  describe "#build_indexes" do
    it "builds entity index by schema" do
      repository.build_indexes

      expect(repository.entity_index.by_schema).to have_key("schema_one")
      expect(repository.entity_index.by_schema).to have_key("schema_two")
      expect(repository.entity_index.by_schema["schema_one"]).to have_key("entity_a")
      expect(repository.entity_index.by_schema["schema_one"]).to have_key("entity_b")
    end

    it "builds entity index by qualified name" do
      repository.build_indexes

      expect(repository.entity_index.by_qualified_name).to have_key("schema_one.entity_a")
      expect(repository.entity_index.by_qualified_name).to have_key("schema_one.entity_b")
      expect(repository.entity_index.by_qualified_name).to have_key("schema_two.entity_c")
    end

    it "builds type index by schema" do
      repository.build_indexes

      expect(repository.type_index.by_schema).to have_key("schema_one")
      expect(repository.type_index.by_schema["schema_one"]).to have_key("type_x")
      expect(repository.type_index.by_schema["schema_one"]).to have_key("type_y")
    end

    it "builds type index by qualified name" do
      repository.build_indexes

      expect(repository.type_index.by_qualified_name).to have_key("schema_one.type_x")
      expect(repository.type_index.by_qualified_name).to have_key("schema_one.type_y")
      expect(repository.type_index.by_qualified_name).to have_key("schema_two.type_z")
    end

    it "builds type index by category" do
      repository.build_indexes

      expect(repository.type_index.by_category).to have_key("select")
      expect(repository.type_index.by_category).to have_key("enumeration")
      expect(repository.type_index.by_category).to have_key("aggregate")
      expect(repository.type_index.by_category["select"].size).to eq(1)
      expect(repository.type_index.by_category["enumeration"].size).to eq(1)
      expect(repository.type_index.by_category["aggregate"].size).to eq(1)
    end

    it "builds reference index with USE FROM relationships" do
      repository.build_indexes

      expect(repository.reference_index.use_from).to have_key("schema_two")
      use_refs = repository.reference_index.use_from["schema_two"]
      expect(use_refs).to be_an(Array)
      expect(use_refs.first[:schema]).to eq("schema_one")
      expect(use_refs.first[:items]).to include("entity_a")
    end

    it "builds reference index with dependencies" do
      repository.build_indexes

      expect(repository.reference_index.dependencies).to have_key("schema_two")
      expect(repository.reference_index.dependencies["schema_two"]).to include("schema_one")
    end
  end

  describe "#find_entity" do
    before { repository.build_indexes }

    it "finds entity by qualified name" do
      entity = repository.find_entity(qualified_name: "schema_one.entity_a")
      expect(entity).not_to be_nil
      expect(entity.id).to eq("entity_a")
    end

    it "finds entity by qualified name case-insensitively" do
      entity = repository.find_entity(qualified_name: "SCHEMA_ONE.ENTITY_A")
      expect(entity).not_to be_nil
      expect(entity.id).to eq("entity_a")
    end

    it "finds entity by simple name when unique" do
      entity = repository.find_entity(qualified_name: "entity_c")
      expect(entity).not_to be_nil
      expect(entity.id).to eq("entity_c")
    end

    it "returns nil for non-existent entity" do
      entity = repository.find_entity(qualified_name: "schema_one.non_existent")
      expect(entity).to be_nil
    end

    it "builds indexes automatically if empty" do
      repo = described_class.new(schemas: [schema1])
      entity = repo.find_entity(qualified_name: "schema_one.entity_a")
      expect(entity).not_to be_nil
    end
  end

  describe "#find_type" do
    before { repository.build_indexes }

    it "finds type by qualified name" do
      type = repository.find_type(qualified_name: "schema_one.type_x")
      expect(type).not_to be_nil
      expect(type.id).to eq("type_x")
    end

    it "finds type by qualified name case-insensitively" do
      type = repository.find_type(qualified_name: "SCHEMA_ONE.TYPE_X")
      expect(type).not_to be_nil
      expect(type.id).to eq("type_x")
    end

    it "finds type by simple name when unique" do
      type = repository.find_type(qualified_name: "type_z")
      expect(type).not_to be_nil
      expect(type.id).to eq("type_z")
    end

    it "returns nil for non-existent type" do
      type = repository.find_type(qualified_name: "schema_one.non_existent")
      expect(type).to be_nil
    end
  end

  describe "#list_entities" do
    before { repository.build_indexes }

    it "lists all entities in object format" do
      entities = repository.list_entities
      expect(entities.size).to eq(3)
      expect(entities.map(&:id)).to contain_exactly("entity_a", "entity_b",
                                                    "entity_c")
    end

    it "lists entities from specific schema" do
      entities = repository.list_entities(schema: "schema_one")
      expect(entities.size).to eq(2)
      expect(entities.map(&:id)).to contain_exactly("entity_a", "entity_b")
    end

    it "lists entities in hash format" do
      entities = repository.list_entities(format: :hash)
      expect(entities).to be_an(Array)
      expect(entities.first).to have_key(:id)
      expect(entities.first).to have_key(:schema)
      expect(entities.first).to have_key(:path)
    end

    it "lists entities in json format" do
      json_output = repository.list_entities(format: :json)
      expect(json_output).to be_a(String)
      entities = JSON.parse(json_output)
      expect(entities).to be_an(Array)
      expect(entities.size).to eq(3)
    end

    it "lists entities in yaml format" do
      yaml_output = repository.list_entities(format: :yaml)
      expect(yaml_output).to be_a(String)
      entities = YAML.safe_load(yaml_output, permitted_classes: [Symbol])
      expect(entities).to be_an(Array)
      expect(entities.size).to eq(3)
    end

    it "returns empty array for non-existent schema" do
      entities = repository.list_entities(schema: "non_existent")
      expect(entities).to be_empty
    end
  end

  describe "#list_types" do
    before { repository.build_indexes }

    it "lists all types in object format" do
      types = repository.list_types
      expect(types.size).to eq(3)
      expect(types.map(&:id)).to contain_exactly("type_x", "type_y", "type_z")
    end

    it "lists types from specific schema" do
      types = repository.list_types(schema: "schema_one")
      expect(types.size).to eq(2)
      expect(types.map(&:id)).to contain_exactly("type_x", "type_y")
    end

    it "lists types by category" do
      types = repository.list_types(category: "select")
      expect(types.size).to eq(1)
      expect(types.first.id).to eq("type_x")
    end

    it "lists types in hash format" do
      types = repository.list_types(format: :hash)
      expect(types).to be_an(Array)
      expect(types.first).to have_key(:id)
      expect(types.first).to have_key(:schema)
      expect(types.first).to have_key(:category)
    end

    it "filters enumeration types" do
      types = repository.list_types(category: "enumeration")
      expect(types.size).to eq(1)
      expect(types.first.id).to eq("type_y")
    end

    it "filters aggregate types" do
      types = repository.list_types(category: "aggregate")
      expect(types.size).to eq(1)
      expect(types.first.id).to eq("type_z")
    end
  end

  describe "#validate" do
    context "with valid repository" do
      it "returns valid status" do
        result = repository.validate
        expect(result[:valid?]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context "with missing schema reference" do
      let(:invalid_schema) do
        Expressir::Model::Declarations::Schema.new(
          id: "invalid_schema",
          entities: [],
          types: [],
          functions: [],
          rules: [],
          procedures: [],
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::References::SimpleReference.new(id: "non_existent"),
              items: [],
            ),
          ],
        )
      end

      let(:invalid_repo) do
        described_class.new(schemas: [invalid_schema])
      end

      it "detects missing schema reference" do
        result = invalid_repo.validate
        expect(result[:valid?]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first[:type]).to eq(:missing_schema_reference)
        expect(result[:errors].first[:referenced_schema]).to eq("non_existent")
      end
    end

    context "with missing interface item" do
      let(:invalid_schema) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema_three",
          entities: [],
          types: [],
          functions: [],
          rules: [],
          procedures: [],
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::References::SimpleReference.new(id: "schema_one"),
              items: [
                Expressir::Model::Declarations::InterfaceItem.new(
                  ref: Expressir::Model::References::SimpleReference.new(id: "non_existent_entity"),
                ),
              ],
            ),
          ],
        )
      end

      let(:invalid_repo) do
        described_class.new(schemas: [schema1, invalid_schema])
      end

      it "detects missing interface item" do
        result = invalid_repo.validate
        expect(result[:valid?]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first[:type]).to eq(:missing_interface_item)
        expect(result[:errors].first[:item]).to eq("non_existent_entity")
      end
    end

    context "with circular dependencies" do
      let(:schema_a) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema_a",
          entities: [],
          types: [],
          functions: [],
          rules: [],
          procedures: [],
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::References::SimpleReference.new(id: "schema_b"),
              items: [],
            ),
          ],
        )
      end

      let(:schema_b) do
        Expressir::Model::Declarations::Schema.new(
          id: "schema_b",
          entities: [],
          types: [],
          functions: [],
          rules: [],
          procedures: [],
          interfaces: [
            Expressir::Model::Declarations::Interface.new(
              kind: Expressir::Model::Declarations::Interface::USE,
              schema: Expressir::Model::References::SimpleReference.new(id: "schema_a"),
              items: [],
            ),
          ],
        )
      end

      let(:circular_repo) do
        described_class.new(schemas: [schema_a, schema_b])
      end

      it "detects circular dependencies" do
        result = circular_repo.validate
        expect(result[:valid?]).to be true # Circular deps are warnings, not errors
        expect(result[:warnings]).not_to be_empty
        expect(result[:warnings].any? do |w|
          w[:type] == :circular_dependency
        end).to be true
      end
    end

    context "in strict mode" do
      it "warns about unused schemas" do
        result = repository.validate(strict: true)
        expect(result[:warnings]).not_to be_empty
        expect(result[:warnings].any? do |w|
          w[:type] == :unused_schema
        end).to be true
      end

      it "does not warn for single schema repository" do
        single_repo = described_class.new(schemas: [schema1])
        result = single_repo.validate(strict: true)
        expect(result[:warnings]).to be_empty
      end
    end
  end

  describe "#statistics" do
    it "returns statistics hash" do
      stats = repository.statistics
      expect(stats).to be_a(Hash)
      expect(stats[:total_schemas]).to eq(2)
      expect(stats[:total_entities]).to eq(3)
      expect(stats[:total_types]).to eq(3)
      expect(stats[:total_functions]).to eq(1)
      expect(stats[:total_rules]).to eq(1)
      expect(stats[:total_procedures]).to eq(1)
    end

    it "includes entities by schema" do
      stats = repository.statistics
      expect(stats[:entities_by_schema]).to have_key("schema_one")
      expect(stats[:entities_by_schema]).to have_key("schema_two")
      expect(stats[:entities_by_schema]["schema_one"]).to eq(2)
      expect(stats[:entities_by_schema]["schema_two"]).to eq(1)
    end

    it "includes types by category" do
      stats = repository.statistics
      expect(stats[:types_by_category]).to have_key(:select)
      expect(stats[:types_by_category]).to have_key(:enumeration)
      expect(stats[:types_by_category]).to have_key(:aggregate)
      expect(stats[:types_by_category][:select]).to eq(1)
      expect(stats[:types_by_category][:enumeration]).to eq(1)
      expect(stats[:types_by_category][:aggregate]).to eq(1)
    end

    it "includes interface counts" do
      stats = repository.statistics
      expect(stats[:interfaces]).to have_key(:use_from)
      expect(stats[:interfaces]).to have_key(:reference_from)
      expect(stats[:interfaces][:use_from]).to eq(1)
      expect(stats[:interfaces][:reference_from]).to eq(0)
    end

    it "returns json format" do
      json_output = repository.statistics(format: :json)
      expect(json_output).to be_a(String)
      stats = JSON.parse(json_output)
      expect(stats["total_schemas"]).to eq(2)
    end

    it "returns yaml format" do
      yaml_output = repository.statistics(format: :yaml)
      expect(yaml_output).to be_a(String)
      stats = YAML.safe_load(yaml_output, permitted_classes: [Symbol])
      expect(stats[:total_schemas]).to eq(2)
    end
  end

  describe "#resolve_all_references" do
    it "calls resolve_all_references which processes the repository" do
      # Use a real visitor instance - the method should not raise errors
      expect do
        repository.resolve_all_references
      end.not_to raise_error
    end

    it "processes repository with schemas" do
      # Resolve references on a repository with schemas
      schema = Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        entities: [Expressir::Model::Declarations::Entity.new(id: "test_entity")],
      )
      repo = described_class.new(schemas: [schema])

      expect do
        repo.resolve_all_references
      end.not_to raise_error
    end
  end

  describe "#children" do
    it "returns schemas as children" do
      expect(repository.children).to eq([schema1, schema2])
    end
  end

  describe ".from_files" do
    let(:syntax_dir) { File.expand_path("../../syntax", __dir__) }
    let(:files) do
      %w[single.exp multiple.exp derived_attribute.exp geometry_schema.exp]
        .map { |f| File.join(syntax_dir, f) }
        .select { |f| File.exist?(f) }
    end

    it "parses in parallel with results identical to sequential" do
      skip "needs at least 3 fixture files and fork" if files.size < 3 ||
        !Expressir::Express::ParallelFiles::FORK_SUPPORTED

      parallel = described_class.from_files(files, max_processes: 4)
      sequential = described_class.from_files(files, max_processes: 1)

      expect(parallel.files.flat_map(&:schemas).map(&:id))
        .to eq(sequential.files.flat_map(&:schemas).map(&:id))
    end

    it "raises on unparseable files even in parallel mode" do
      skip "needs fork" unless Expressir::Express::ParallelFiles::FORK_SUPPORTED

      bad = Tempfile.new(%w[bad .exp])
      begin
        bad.write("ENTITY broken")
        bad.flush

        expect do
          described_class.from_files(files + [bad.path], max_processes: 4)
        end.to raise_error(Expressir::Express::Error::SchemaParseFailure)
      ensure
        bad.close
        bad.unlink
      end
    end
  end
end
