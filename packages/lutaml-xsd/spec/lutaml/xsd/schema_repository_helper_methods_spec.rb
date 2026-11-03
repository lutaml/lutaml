# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::SchemaRepository, "helper methods" do
  let(:schema_files) do
    [
      File.expand_path("../../fixtures/metaschema.xsd", __dir__),
    ]
  end

  let(:schema_location_mappings) do
    [
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-datatypes.xsd",
        to: File.expand_path("../../fixtures/metaschema-datatypes.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-base.xsd",
        to: File.expand_path("../../fixtures/metaschema-prose-base.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-line.xsd",
        to: File.expand_path("../../fixtures/metaschema-markup-line.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-markup-multiline.xsd",
        to: File.expand_path("../../fixtures/metaschema-markup-multiline.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-prose-module.xsd",
        to: File.expand_path("../../fixtures/metaschema-prose-module.xsd",
                             __dir__),
        pattern: false,
      ),
      Lutaml::Xsd::SchemaLocationMapping.new(
        from: "metaschema-meta-constraints.xsd",
        to: File.expand_path("../../fixtures/metaschema-meta-constraints.xsd",
                             __dir__),
        pattern: false,
      ),
    ]
  end

  let(:namespace_mappings) do
    {
      "xs" => "http://www.w3.org/2001/XMLSchema",
      "m" => "http://csrc.nist.gov/ns/oscal/metaschema/1.0",
    }
  end

  let(:repository) do
    described_class.new(
      files: schema_files,
      schema_location_mappings: schema_location_mappings,
    ).tap do |repo|
      repo.configure_namespaces(namespace_mappings)
      repo.parse
      repo.resolve
    end
  end

  describe "#type_exists?" do
    it "returns true for existing types" do
      # Get all type names from the repository without filtering
      all_types = repository.all_type_names

      # Repository should have some types
      expect(all_types).not_to be_empty

      result = repository.type_exists?(all_types.first)
      expect(result).to be true
    end

    it "returns false for non-existent types" do
      result = repository.type_exists?("m:NonExistentType")
      expect(result).to be false
    end

    it "returns false for unregistered namespace prefixes" do
      result = repository.type_exists?("unknown:SomeType")
      expect(result).to be false
    end
  end

  describe "#all_type_names" do
    it "returns an array of qualified type names" do
      type_names = repository.all_type_names
      expect(type_names).to be_an(Array)
      expect(type_names).not_to be_empty
    end

    it "returns sorted type names" do
      type_names = repository.all_type_names
      expect(type_names).to eq(type_names.sort)
    end

    it "filters by namespace when specified" do
      # Get all namespaces first
      all_namespaces = repository.all_namespaces
      expect(all_namespaces).not_to be_empty

      # Filter by first available namespace
      first_ns = all_namespaces.first
      type_names = repository.all_type_names(namespace: first_ns)
      expect(type_names).to be_an(Array)

      # If there are types, they should be from the specified namespace
      if type_names.any?
        prefix = repository.instance_variable_get(:@namespace_registry)
          .prefix_for(first_ns)
        type_names.each do |name|
          expect(name).to start_with("#{prefix}:")
        end
      end
    end

    it "filters by category when specified" do
      complex_types = repository.all_type_names(category: :complex_type)
      expect(complex_types).to be_an(Array)
    end

    it "filters by both namespace and category" do
      all_namespaces = repository.all_namespaces
      first_ns = all_namespaces.first

      filtered_types = repository.all_type_names(
        namespace: first_ns,
        category: :complex_type,
      )
      expect(filtered_types).to be_an(Array)
    end

    it "returns empty array when no types match filter" do
      fake_ns = "http://nonexistent.namespace.example"
      type_names = repository.all_type_names(namespace: fake_ns)
      expect(type_names).to be_empty
    end
  end

  describe "#export_statistics" do
    context "with YAML format" do
      it "exports statistics as YAML" do
        yaml_output = repository.export_statistics(format: :yaml)
        expect(yaml_output).to be_a(String)
        expect(yaml_output).to include("total_schemas:")
        expect(yaml_output).to include("total_types:")
      end

      it "produces valid YAML" do
        yaml_output = repository.export_statistics(format: :yaml)
        parsed = YAML.safe_load(yaml_output, permitted_classes: [Symbol])
        expect(parsed).to be_a(Hash)
        # YAML keys are loaded as symbols or strings depending on configuration
        expect(parsed.key?("total_schemas") || parsed.key?(:total_schemas)).to be true
      end
    end

    context "with JSON format" do
      it "exports statistics as JSON" do
        json_output = repository.export_statistics(format: :json)
        expect(json_output).to be_a(String)
        expect(json_output).to include('"total_schemas"')
        expect(json_output).to include('"total_types"')
      end

      it "produces valid JSON" do
        json_output = repository.export_statistics(format: :json)
        parsed = JSON.parse(json_output)
        expect(parsed).to be_a(Hash)
        expect(parsed).to have_key("total_schemas")
      end
    end

    context "with text format" do
      it "exports statistics as human-readable text" do
        text_output = repository.export_statistics(format: :text)
        expect(text_output).to be_a(String)
        expect(text_output).to include("Schema Repository Statistics")
        expect(text_output).to include("Total Schemas:")
        expect(text_output).to include("Total Types:")
      end

      it "includes all relevant statistics" do
        text_output = repository.export_statistics(format: :text)
        expect(text_output).to include("Total Namespaces:")
        expect(text_output).to include("Types by Category:")
        expect(text_output).to include("Resolved:")
        expect(text_output).to include("Validated:")
      end
    end

    context "with unsupported format" do
      it "raises ArgumentError" do
        expect do
          repository.export_statistics(format: :xml)
        end.to raise_error(ArgumentError, /Unsupported format/)
      end
    end

    context "with default format" do
      it "defaults to YAML format" do
        default_output = repository.export_statistics
        yaml_output = repository.export_statistics(format: :yaml)
        expect(default_output).to eq(yaml_output)
      end
    end
  end

  describe "#namespace_summary" do
    it "returns an array of namespace summaries" do
      summary = repository.namespace_summary
      expect(summary).to be_an(Array)
      expect(summary).not_to be_empty
    end

    it "includes namespace URIs in summary" do
      summary = repository.namespace_summary
      summary.each do |ns_info|
        expect(ns_info).to have_key(:uri)
        expect(ns_info[:uri]).to be_a(String)
      end
    end

    it "includes namespace prefixes in summary" do
      summary = repository.namespace_summary
      summary.each do |ns_info|
        expect(ns_info).to have_key(:prefix)
      end
    end

    it "includes type counts in summary" do
      summary = repository.namespace_summary
      summary.each do |ns_info|
        expect(ns_info).to have_key(:types)
        expect(ns_info[:types]).to be_a(Integer)
        expect(ns_info[:types]).to be >= 0
      end
    end

    it "returns correct structure for each namespace" do
      summary = repository.namespace_summary
      first_ns = summary.first
      expect(first_ns.keys).to match_array(%i[uri prefix types])
    end
  end

  describe "integration with existing methods" do
    it "type_exists? works with find_type" do
      # Use an actual type from the repository
      type_names = repository.all_type_names
      expect(type_names).not_to be_empty

      type_name = type_names.first
      exists = repository.type_exists?(type_name)
      find_result = repository.find_type(type_name)

      expect(exists).to eq(find_result.resolved?)
    end

    it "all_type_names returns types findable with find_type" do
      type_names = repository.all_type_names.take(5)

      type_names.each do |name|
        result = repository.find_type(name)
        expect(result).to be_a(Lutaml::Xsd::TypeResolutionResult)
      end
    end

    it "namespace_summary matches all_namespaces" do
      summary = repository.namespace_summary
      all_ns = repository.all_namespaces

      summary_uris = summary.map { |ns| ns[:uri] }.sort
      expect(summary_uris).to eq(all_ns.sort)
    end
  end
end
