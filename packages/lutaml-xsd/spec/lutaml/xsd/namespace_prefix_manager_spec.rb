# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"

RSpec.describe Lutaml::Xsd::NamespacePrefixManager do
  let(:repository) do
    repo = Lutaml::Xsd::SchemaRepository.new(
      namespace_mappings: [
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "gml",
          uri: "http://www.opengis.net/gml/3.2",
        ),
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "xlink",
          uri: "http://www.w3.org/1999/xlink",
        ),
      ],
    )
    repo.instance_variable_set(:@resolved, true)
    repo
  end

  let(:manager) { described_class.new(repository) }

  describe "#initialize" do
    it "sets the repository" do
      expect(manager.repository).to eq(repository)
    end
  end

  describe "#detailed_prefix_info" do
    it "returns array of NamespacePrefixInfo objects" do
      info_list = manager.detailed_prefix_info

      expect(info_list).to be_an(Array)
      expect(info_list.size).to eq(2)
      expect(info_list).to all(be_a(Lutaml::Xsd::NamespacePrefixInfo))
    end

    it "includes prefix and URI information" do
      info_list = manager.detailed_prefix_info

      gml_info = info_list.find { |i| i.prefix == "gml" }
      expect(gml_info).not_to be_nil
      expect(gml_info.uri).to eq("http://www.opengis.net/gml/3.2")

      xlink_info = info_list.find { |i| i.prefix == "xlink" }
      expect(xlink_info).not_to be_nil
      expect(xlink_info.uri).to eq("http://www.w3.org/1999/xlink")
    end
  end

  describe "#find_schema_for_namespace" do
    it "returns nil when namespace not found" do
      schema = manager.find_schema_for_namespace("http://example.com/unknown")
      expect(schema).to be_nil
    end

    it "finds schema for namespace" do
      # Create a mock schema with target namespace
      schema = double("Schema", target_namespace: "http://www.opengis.net/gml/3.2")
      allow(repository).to receive(:all_schemas)
        .and_return({ "test.xsd" => schema })

      result = manager.find_schema_for_namespace("http://www.opengis.net/gml/3.2")
      expect(result).to eq(schema)
    end
  end

  describe "#get_package_location" do
    it "returns nil when namespace not found" do
      location = manager.get_package_location("http://example.com/unknown")
      expect(location).to be_nil
    end

    it "returns file path for namespace" do
      schema = double("Schema", target_namespace: "http://www.opengis.net/gml/3.2")
      allow(repository).to receive(:all_schemas)
        .and_return({ "/path/to/gml.xsd" => schema })

      location = manager.get_package_location("http://www.opengis.net/gml/3.2")
      expect(location).to eq("/path/to/gml.xsd")
    end
  end
end

RSpec.describe Lutaml::Xsd::NamespacePrefixInfo do
  let(:mapping) do
    Lutaml::Xsd::NamespaceMapping.new(
      prefix: "test",
      uri: "http://example.com/test",
    )
  end

  let(:repository) do
    repo = Lutaml::Xsd::SchemaRepository.new(
      namespace_mappings: [mapping],
    )
    repo.instance_variable_set(:@resolved, true)

    allow(repo).to receive(:all_schemas).and_return({})
    allow(repo).to receive(:types_in_namespace).and_return(
      [
        { type: :complex_type,
          definition: double(name: "TypeA") },
        { type: :simple_type,
          definition: double(name: "TypeB") },
        { type: :complex_type,
          definition: double(name: "TypeC") },
      ],
    )
    repo
  end

  let(:info) { described_class.new(mapping, repository) }

  describe "#initialize" do
    it "sets prefix and uri from mapping" do
      expect(info.prefix).to eq("test")
      expect(info.uri).to eq("http://example.com/test")
    end

    it "calculates type counts" do
      expect(info.type_count).to eq(3)
    end

    it "groups types by category" do
      expect(info.types_by_category).to eq({
                                             complex_type: 2,
                                             simple_type: 1,
                                           })
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      hash = info.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:prefix]).to eq("test")
      expect(hash[:uri]).to eq("http://example.com/test")
      expect(hash[:type_count]).to eq(3)
      expect(hash[:types_by_category]).to eq({
                                               complex_type: 2,
                                               simple_type: 1,
                                             })
    end

    it "includes all required fields" do
      hash = info.to_h

      expect(hash).to have_key(:prefix)
      expect(hash).to have_key(:uri)
      expect(hash).to have_key(:original_schema_location)
      expect(hash).to have_key(:package_location)
      expect(hash).to have_key(:type_count)
      expect(hash).to have_key(:types_by_category)
    end
  end
end
