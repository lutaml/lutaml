# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaClassifier do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:classifier) { described_class.new(repository) }

  describe "#initialize" do
    it "stores the repository" do
      expect(classifier.repository).to eq(repository)
    end
  end

  describe "#classify" do
    context "with empty repository" do
      before do
        # Clear global schema cache to ensure truly empty repository
        Lutaml::Xml::Schema::Xsd::Schema.reset_processed_schemas
      end

      it "returns classification structure with empty categories" do
        result = classifier.classify

        expect(result).to be_a(Hash)
        expect(result).to include(
          :entrypoint_schemas,
          :dependency_schemas,
          :fully_resolved,
          :partially_resolved,
          :summary,
        )
        expect(result[:entrypoint_schemas]).to eq([])
        expect(result[:dependency_schemas]).to eq([])
      end

      it "returns summary with zero counts" do
        result = classifier.classify
        summary = result[:summary]

        expect(summary[:total_schemas]).to eq(0)
        expect(summary[:entrypoint_count]).to eq(0)
        expect(summary[:dependency_count]).to eq(0)
        expect(summary[:fully_resolved_count]).to eq(0)
        expect(summary[:partially_resolved_count]).to eq(0)
        expect(summary[:resolution_percentage]).to eq(0.0)
      end
    end

    context "with mock schemas in processed cache" do
      let(:schema1_path) { "/path/to/schema1.xsd" }
      let(:schema2_path) { "/path/to/schema2.xsd" }
      let(:schema1) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Schema,
          target_namespace: "http://example.com/schema1",
          element: [],
          complex_type: [],
          simple_type: [],
          import: [],
          include: [],
        )
      end
      let(:schema2) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Schema,
          target_namespace: "http://example.com/schema2",
          element: [],
          complex_type: [],
          simple_type: [],
          import: [],
          include: [],
        )
      end

      before do
        # Clear and setup processed schemas
        Lutaml::Xml::Schema::Xsd::Schema.reset_processed_schemas
        Lutaml::Xml::Schema::Xsd::Schema.schema_processed(schema1_path, schema1)
        Lutaml::Xml::Schema::Xsd::Schema.schema_processed(schema2_path, schema2)
        repository.instance_variable_set(:@files, [schema1_path])
      end

      after do
        Lutaml::Xml::Schema::Xsd::Schema.reset_processed_schemas
      end

      it "classifies entrypoint schemas correctly" do
        result = classifier.classify
        entrypoints = result[:entrypoint_schemas]

        expect(entrypoints.size).to eq(1)
        expect(entrypoints.first).to be_a(Lutaml::Xsd::SchemaClassificationInfo)
        expect(entrypoints.first.category).to eq(:entrypoint)
        expect(entrypoints.first.location).to eq(schema1_path)
      end

      it "classifies dependency schemas correctly" do
        result = classifier.classify
        dependencies = result[:dependency_schemas]

        expect(dependencies.size).to eq(1)
        expect(dependencies.first).to be_a(Lutaml::Xsd::SchemaClassificationInfo)
        expect(dependencies.first.category).to eq(:dependency)
        expect(dependencies.first.location).to eq(schema2_path)
      end

      it "generates accurate summary statistics" do
        result = classifier.classify
        summary = result[:summary]

        expect(summary[:total_schemas]).to eq(2)
        expect(summary[:entrypoint_count]).to eq(1)
        expect(summary[:dependency_count]).to eq(1)
        expect(summary[:fully_resolved_count]).to eq(2)
        expect(summary[:partially_resolved_count]).to eq(0)
        expect(summary[:resolution_percentage]).to eq(100.0)
      end
    end
  end

  describe "private methods" do
    describe "#calculate_resolution_percentage" do
      it "returns 0 for zero total" do
        percentage = classifier.send(:calculate_resolution_percentage, 0, 0)
        expect(percentage).to eq(0.0)
      end

      it "calculates percentage correctly" do
        percentage = classifier.send(:calculate_resolution_percentage, 3, 10)
        expect(percentage).to eq(30.0)
      end

      it "rounds to 2 decimal places" do
        percentage = classifier.send(:calculate_resolution_percentage, 1, 3)
        expect(percentage).to eq(33.33)
      end

      it "handles 100% correctly" do
        percentage = classifier.send(:calculate_resolution_percentage, 10, 10)
        expect(percentage).to eq(100.0)
      end
    end

    describe "#determine_category" do
      before do
        repository.instance_variable_set(:@files, ["/path/to/schema.xsd"])
      end

      it "identifies entrypoint schemas" do
        category = classifier.send(:determine_category, "/path/to/schema.xsd")
        expect(category).to eq(:entrypoint)
      end

      it "identifies dependency schemas" do
        category = classifier.send(:determine_category, "/path/to/other.xsd")
        expect(category).to eq(:dependency)
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::SchemaClassificationInfo do
  let(:schema) do
    instance_double(
      Lutaml::Xml::Schema::Xsd::Schema,
      target_namespace: "http://example.com/schema",
      element: [],
      complex_type: [],
      simple_type: [],
      import: [],
      include: [],
    )
  end

  let(:location) { "/path/to/schema.xsd" }
  let(:category) { :entrypoint }
  let(:info) do
    described_class.new(schema: schema, location: location, category: category)
  end

  describe "#initialize" do
    it "extracts basic information from schema" do
      expect(info.location).to eq(location)
      expect(info.category).to eq(category)
      expect(info.namespace).to eq("http://example.com/schema")
    end

    it "counts elements correctly" do
      allow(schema).to receive(:element).and_return([1, 2, 3])
      info = described_class.new(schema: schema, location: location,
                                 category: category)
      expect(info.elements_count).to eq(3)
    end

    it "counts types correctly" do
      allow(schema).to receive(:complex_type).and_return([1, 2])
      allow(schema).to receive(:simple_type).and_return([1, 2, 3])
      info = described_class.new(schema: schema, location: location,
                                 category: category)
      expect(info.types_count).to eq(5)
    end
  end

  describe "#fully_resolved?" do
    context "with no external references" do
      it "returns true" do
        expect(info.fully_resolved?).to be true
      end
    end

    context "with unresolved external references" do
      let(:import_obj) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Import,
          namespace: "http://example.com/other",
          schema_path: "/path/to/unresolved.xsd",
        )
      end

      before do
        allow(schema).to receive(:import).and_return([import_obj])
        allow(Lutaml::Xml::Schema::Xsd::Schema).to receive(:schema_processed?)
          .with("/path/to/unresolved.xsd")
          .and_return(false)
      end

      it "returns false" do
        info = described_class.new(schema: schema, location: location,
                                   category: category)
        expect(info.fully_resolved?).to be false
      end
    end
  end

  describe "#partially_resolved?" do
    it "is opposite of fully_resolved?" do
      expect(info.partially_resolved?).to eq(!info.fully_resolved?)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = info.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:location]).to eq(location)
      expect(hash[:filename]).to eq("schema.xsd")
      expect(hash[:category]).to eq(category)
      expect(hash[:namespace]).to eq("http://example.com/schema")
      expect(hash[:elements_count]).to eq(0)
      expect(hash[:types_count]).to eq(0)
      expect(%i[fully_resolved
                partially_resolved]).to include(hash[:resolution_status])
    end

    it "handles nil namespace" do
      allow(schema).to receive(:target_namespace).and_return(nil)
      info = described_class.new(schema: schema, location: location,
                                 category: category)
      hash = info.to_h

      expect(hash[:namespace]).to eq("(no namespace)")
    end

    it "includes correct counts" do
      elem1 = instance_double(Lutaml::Xml::Schema::Xsd::Element)
      elem2 = instance_double(Lutaml::Xml::Schema::Xsd::Element)
      type1 = instance_double(Lutaml::Xml::Schema::Xsd::ComplexType)
      type2 = instance_double(Lutaml::Xml::Schema::Xsd::ComplexType)
      type3 = instance_double(Lutaml::Xml::Schema::Xsd::ComplexType)
      stype1 = instance_double(Lutaml::Xml::Schema::Xsd::SimpleType)
      import1 = instance_double(Lutaml::Xml::Schema::Xsd::Import, namespace: "ns1",
                                                                  schema_path: nil)
      import2 = instance_double(Lutaml::Xml::Schema::Xsd::Import, namespace: "ns2",
                                                                  schema_path: nil)
      include1 = instance_double(Lutaml::Xml::Schema::Xsd::Include,
                                 schema_path: nil)

      allow(schema).to receive(:element).and_return([elem1, elem2])
      allow(schema).to receive(:complex_type).and_return([type1, type2, type3])
      allow(schema).to receive(:simple_type).and_return([stype1])
      allow(schema).to receive(:import).and_return([import1, import2])
      allow(schema).to receive(:include).and_return([include1])

      info = described_class.new(schema: schema, location: location,
                                 category: category)
      hash = info.to_h

      expect(hash[:elements_count]).to eq(2)
      expect(hash[:complex_types_count]).to eq(3)
      expect(hash[:simple_types_count]).to eq(1)
      expect(hash[:types_count]).to eq(4)
      expect(hash[:imports_count]).to eq(2)
      expect(hash[:includes_count]).to eq(1)
    end
  end

  describe "external references extraction" do
    let(:import_obj) do
      instance_double(
        Lutaml::Xml::Schema::Xsd::Import,
        namespace: "http://example.com/import",
        schema_path: "/path/to/import.xsd",
      )
    end

    let(:include_obj) do
      instance_double(
        Lutaml::Xml::Schema::Xsd::Include,
        schema_path: "/path/to/include.xsd",
      )
    end

    before do
      allow(schema).to receive(:import).and_return([import_obj])
      allow(schema).to receive(:include).and_return([include_obj])
    end

    it "extracts import references" do
      info = described_class.new(schema: schema, location: location,
                                 category: category)
      hash = info.to_h

      expect(hash[:external_refs_count]).to eq(2)
    end
  end

  describe "resolution status determination" do
    context "with all references resolved" do
      let(:import_obj) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Import,
          namespace: "http://example.com/import",
          schema_path: "/path/to/import.xsd",
        )
      end

      before do
        allow(schema).to receive(:import).and_return([import_obj])
        allow(Lutaml::Xml::Schema::Xsd::Schema).to receive(:schema_processed?)
          .with("/path/to/import.xsd")
          .and_return(true)
      end

      it "sets status to fully_resolved" do
        info = described_class.new(schema: schema, location: location,
                                   category: category)
        expect(info.to_h[:resolution_status]).to eq(:fully_resolved)
      end
    end

    context "with unresolved references" do
      let(:import_obj) do
        instance_double(
          Lutaml::Xml::Schema::Xsd::Import,
          namespace: "http://example.com/import",
          schema_path: "/path/to/unresolved.xsd",
        )
      end

      before do
        allow(schema).to receive(:import).and_return([import_obj])
        allow(Lutaml::Xml::Schema::Xsd::Schema).to receive(:schema_processed?)
          .with("/path/to/unresolved.xsd")
          .and_return(false)
      end

      it "sets status to partially_resolved" do
        info = described_class.new(schema: schema, location: location,
                                   category: category)
        expect(info.to_h[:resolution_status]).to eq(:partially_resolved)
      end
    end
  end
end
