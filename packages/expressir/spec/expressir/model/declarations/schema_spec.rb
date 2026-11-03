require "spec_helper"
require "tempfile"
require "liquid"

RSpec.describe Expressir::Model::Declarations::Schema do
  let(:interface) do
    Expressir::Model::Declarations::Interface.new(
      kind: Expressir::Model::Declarations::Interface::USE,
      schema: Expressir::Model::References::SimpleReference.new(id: "source_schema"),
      items: [
        Expressir::Model::Declarations::InterfaceItem.new(
          ref: Expressir::Model::References::SimpleReference.new(id: "source_type"),
          id: "renamed_type",
        ),
      ],
    )
  end

  let(:constant) do
    Expressir::Model::Declarations::Constant.new(
      id: "test_constant",
      type: Expressir::Model::DataTypes::Integer.new,
      expression: Expressir::Model::Literals::Integer.new(value: "42"),
    )
  end

  let(:type) do
    Expressir::Model::Declarations::Type.new(
      id: "test_type",
      underlying_type: Expressir::Model::DataTypes::String.new,
    )
  end

  let(:entity) do
    Expressir::Model::Declarations::Entity.new(
      id: "test_entity",
      attributes: [
        Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::Integer.new,
        ),
      ],
    )
  end

  let(:subtype_constraint) do
    Expressir::Model::Declarations::SubtypeConstraint.new(
      id: "test_constraint",
      applies_to: Expressir::Model::References::SimpleReference.new(id: "test_entity"),
    )
  end

  let(:function) do
    Expressir::Model::Declarations::Function.new(
      id: "test_function",
      return_type: Expressir::Model::DataTypes::Integer.new,
    )
  end

  let(:rule) do
    Expressir::Model::Declarations::Rule.new(
      id: "test_rule",
      applies_to: [Expressir::Model::References::SimpleReference.new(id: "test_entity")],
    )
  end

  let(:procedure) do
    Expressir::Model::Declarations::Procedure.new(
      id: "test_procedure",
    )
  end

  let(:schema) do
    described_class.new(
      id: "test_schema",
      file: "test_schema.exp",
      version: Expressir::Model::Declarations::SchemaVersion.new(value: "{1}"),
      interfaces: [interface],
      constants: [constant],
      types: [type],
      entities: [entity],
      subtype_constraints: [subtype_constraint],
      functions: [function],
      rules: [rule],
      procedures: [procedure],
      remarks: ["Schema remark"],
      remark_items: [
        Expressir::Model::Declarations::RemarkItem.new(id: "remark1"),
      ],
    )
  end

  let(:source_type) do
    Expressir::Model::Declarations::Type.new(
      id: "source_type",
      underlying_type: Expressir::Model::DataTypes::String.new,
    )
  end

  let(:source_schema) do
    described_class.new(
      id: "source_schema",
      types: [source_type],
    )
  end

  let(:repository) do
    Expressir::Model::Repository.new(
      schemas: [source_schema, schema],
    )
  end

  describe ".new" do
    it "creates a schema with all attributes" do
      expect(schema).to be_a described_class
      expect(schema.id).to eq "test_schema"
      expect(schema.file).to eq "test_schema.exp"
      expect(schema.version).to be_a Expressir::Model::Declarations::SchemaVersion
      expect(schema.version.value).to eq "{1}"
      expect(schema.interfaces).to contain_exactly(interface)
      expect(schema.constants).to contain_exactly(constant)
      expect(schema.types).to contain_exactly(type)
      expect(schema.entities).to contain_exactly(entity)
      expect(schema.subtype_constraints).to contain_exactly(subtype_constraint)
      expect(schema.functions).to contain_exactly(function)
      expect(schema.rules).to contain_exactly(rule)
      expect(schema.procedures).to contain_exactly(procedure)
      expect(schema.remarks).to eq ["Schema remark"]
      expect(schema.remark_items.size).to eq 1
      expect(schema.remark_items.first.id).to eq "remark1"
    end

    it "creates a schema with minimal attributes" do
      schema = described_class.new(id: "minimal_schema")
      expect(schema.id).to eq "minimal_schema"
      expect(schema.file).to be_nil
      expect(schema.version).to be_nil
      expect(schema.interfaces).to eq([])
      expect(schema.constants).to eq([])
      expect(schema.types).to eq([])
      expect(schema.entities).to eq([])
      expect(schema.subtype_constraints).to eq([])
      expect(schema.functions).to eq([])
      expect(schema.rules).to eq([])
      expect(schema.procedures).to eq([])
      expect(schema.remarks).to eq([])
      expect(schema.remark_items).to eq([])
    end
  end

  describe "inheritance" do
    it "inherits from ModelElement" do
      expect(schema).to be_a Expressir::Model::ModelElement
    end

    it "includes Identifier module" do
      expect(described_class.included_modules).to include(Expressir::Model::Identifier)
    end
  end

  describe "#children" do
    before do
      schema.parent = repository
    end

    it "returns all child elements including interfaced items" do
      children = schema.children
      # children includes interfaced_items (resolved from interfaces)
      # The interface references source_type renamed to renamed_type
      interfaced_item = children.find { |c| c.is_a?(Expressir::Model::Declarations::InterfacedItem) && c.id == "renamed_type" }
      expect(interfaced_item).not_to be_nil
      expect(interfaced_item.base_item).to eq(source_type)
      expect(children).to include(constant)
      expect(children).to include(type)
      expect(children).to include(entity)
      expect(children).to include(subtype_constraint)
      expect(children).to include(function)
      expect(children).to include(rule)
      expect(children).to include(procedure)
      expect(children).to include(schema.remark_items.first)
    end

    it "returns safe children without interfaced items" do
      safe_children = schema.safe_children
      expect(safe_children).not_to include(interface)
      expect(safe_children).to include(constant)
      expect(safe_children).to include(type)
      expect(safe_children).to include(entity)
      expect(safe_children).to include(subtype_constraint)
      expect(safe_children).to include(function)
      expect(safe_children).to include(rule)
      expect(safe_children).to include(procedure)
      expect(safe_children).to include(schema.remark_items.first)
    end
  end

  describe "path resolution" do
    before do
      schema.parent = repository
    end

    it "provides path for itself" do
      expect(schema.path).to eq "test_schema"
    end

    it "provides path for children" do
      expect(entity.path).to eq "test_schema.test_entity"
      expect(type.path).to eq "test_schema.test_type"
      expect(function.path).to eq "test_schema.test_function"
    end
  end

  describe "interfaced items" do
    let(:source_schema) do
      described_class.new(
        id: "source_schema",
        types: [
          Expressir::Model::Declarations::Type.new(
            id: "source_type",
            underlying_type: Expressir::Model::DataTypes::Integer.new,
          ),
        ],
      )
    end

    before do
      repository.add_schema(source_schema)
      schema.parent = repository
      source_schema.parent = repository
    end

    it "creates interfaced items from referenced schema" do
      interfaced_items = schema.send(:interfaced_items)
      expect(interfaced_items.size).to eq 1
      expect(interfaced_items.first).to be_a Expressir::Model::Declarations::InterfacedItem
      expect(interfaced_items.first.id).to eq "renamed_type"
      expect(interfaced_items.first.base_item.id).to eq "source_type"
    end

    it "includes interfaced items in children" do
      children = schema.children
      interfaced_items = children.grep(Expressir::Model::Declarations::InterfacedItem)
      expect(interfaced_items.size).to eq 1
      expect(interfaced_items.first.id).to eq "renamed_type"
    end
  end

  describe "#source and #source_hyperlinked (#255)" do
    # Two files: HyperlinkFormatter suppresses links whose target lives in
    # the same file as the reference (same-document anchors), so the
    # cross-schema marker only appears across the file boundary.
    let(:faces_b) do
      file_a = Tempfile.new(["schema_faces_a", ".exp"])
      file_b = Tempfile.new(["schema_faces_b", ".exp"])
      begin
        file_a.write(<<~EXP)
          SCHEMA faces_a;
          TYPE surface_model = STRING; END_TYPE;
          END_SCHEMA;
        EXP
        file_a.close
        file_b.write(<<~EXP)
          SCHEMA faces_b;
          USE FROM faces_a (surface_model);
          ENTITY b_spline;
            model : surface_model;
          END_ENTITY;
          END_SCHEMA;
        EXP
        file_b.close
        repository = Expressir::Express::Parser.from_files([file_a.path, file_b.path])
        repository.schemas.find { |s| s.id == "faces_b" }
      ensure
        file_a.unlink
        file_b.unlink
      end
    end

    it "returns the schema head without hyperlinks" do
      aggregate_failures do
        expect(faces_b.source).to include("SCHEMA faces_b")
        expect(faces_b.source).to include("USE FROM faces_a")
        expect(faces_b.source).not_to include("ENTITY b_spline")
        expect(faces_b.source).not_to include("<<express:")
      end
    end

    it "returns the schema head with cross-schema links hyperlinked" do
      aggregate_failures do
        expect(faces_b.source_hyperlinked).to include("SCHEMA faces_b")
        expect(faces_b.source_hyperlinked).not_to include("ENTITY b_spline")
        expect(faces_b.source_hyperlinked)
          .to match(/\{\{\{<<express:[^,]+\.surface_model,surface_model>>\}\}\}/)
      end
    end

    it "returns the FULL schema text hyperlinked" do
      aggregate_failures do
        expect(faces_b.formatted_hyperlinked).to include("SCHEMA faces_b")
        expect(faces_b.formatted_hyperlinked).to include("ENTITY b_spline")
        expect(faces_b.formatted_hyperlinked)
          .to match(/\{\{\{<<express:[^,]+\.surface_model,surface_model>>\}\}\}/)
      end
    end

    it "returns the FULL schema text with AsciiDoc xref macros" do
      aggregate_failures do
        expect(faces_b.formatted_hyperlinked_adoc).to include("ENTITY b_spline")
        expect(faces_b.formatted_hyperlinked_adoc)
          .to include("<<faces_a.surface_model,surface_model>>")
        expect(faces_b.formatted_hyperlinked_adoc).not_to include("{{{")
      end
    end

    it "exposes both faces through the Liquid Drop" do
      plain = Liquid::Template.parse("{{ schema.source }}").render("schema" => faces_b)
      hyperlinked = Liquid::Template
        .parse("{{ schema.source_hyperlinked }}").render("schema" => faces_b)
      aggregate_failures do
        expect(plain).to include("SCHEMA faces_b")
        expect(plain).not_to include("ENTITY b_spline")
        expect(plain).not_to include("<<express:")
        expect(hyperlinked).to match(/<<express:[^,]+\.surface_model,surface_model>>/)
      end
    end
  end
end
