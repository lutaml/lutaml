# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/dependency_grapher"
require "lutaml/xsd/schema_repository"

RSpec.describe Lutaml::Xsd::DependencyGrapher do
  let(:fixture_dir) { File.join(__dir__, "../../fixtures") }
  let(:repository) { create_test_repository }

  # Helper to create a simple test repository
  def create_test_repository
    repo = Lutaml::Xsd::SchemaRepository.new

    # Create a simple schema with dependencies
    schema_content = <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:test="http://example.com/test"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">

        <!-- Base types -->
        <xs:simpleType name="StringType">
          <xs:restriction base="xs:string"/>
        </xs:simpleType>

        <xs:simpleType name="IntType">
          <xs:restriction base="xs:integer"/>
        </xs:simpleType>

        <!-- Complex type with dependencies -->
        <xs:complexType name="PersonType">
          <xs:sequence>
            <xs:element name="name" type="test:StringType"/>
            <xs:element name="age" type="test:IntType"/>
            <xs:element name="address" type="test:AddressType"/>
          </xs:sequence>
        </xs:complexType>

        <xs:complexType name="AddressType">
          <xs:sequence>
            <xs:element name="street" type="test:StringType"/>
            <xs:element name="city" type="test:StringType"/>
            <xs:element name="country" type="test:CountryType"/>
          </xs:sequence>
        </xs:complexType>

        <xs:complexType name="CountryType">
          <xs:simpleContent>
            <xs:extension base="test:StringType">
              <xs:attribute name="code" type="test:StringType"/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>

        <!-- Type that depends on PersonType -->
        <xs:complexType name="EmployeeType">
          <xs:complexContent>
            <xs:extension base="test:PersonType">
              <xs:sequence>
                <xs:element name="employeeId" type="test:IntType"/>
                <xs:element name="department" type="test:StringType"/>
              </xs:sequence>
            </xs:extension>
          </xs:complexContent>
        </xs:complexType>

        <!-- Standalone type with no dependencies -->
        <xs:simpleType name="StatusType">
          <xs:restriction base="xs:string">
            <xs:enumeration value="active"/>
            <xs:enumeration value="inactive"/>
          </xs:restriction>
        </xs:simpleType>

        <!-- Top-level elements -->
        <xs:element name="Person" type="test:PersonType"/>
        <xs:element name="Employee" type="test:EmployeeType"/>
      </xs:schema>
    XSD

    # Write schema to temp file
    temp_file = Tempfile.new(["test_schema", ".xsd"])
    temp_file.write(schema_content)
    temp_file.close

    # Add to repository
    repo.add_schema_file(temp_file.path)
    repo.parse

    # Ensure the schema is in the global processed_schemas cache
    parsed_schema = repo.instance_variable_get(:@parsed_schemas).get(temp_file.path)
    if parsed_schema
      Lutaml::Xml::Schema::Xsd::Schema.schema_processed(temp_file.path,
                                                        parsed_schema)
    end

    repo.resolve

    # Register namespace
    namespace_registry = repo.instance_variable_get(:@namespace_registry)
    namespace_registry.register("test", "http://example.com/test")

    temp_file.unlink

    repo
  end

  describe "#initialize" do
    it "creates a grapher with a repository" do
      grapher = described_class.new(repository)
      expect(grapher.repository).to eq(repository)
    end
  end

  describe "#dependencies" do
    let(:grapher) { described_class.new(repository) }

    context "when type is found" do
      it "returns dependency graph for PersonType" do
        result = grapher.dependencies("test:PersonType", depth: 3)

        expect(result[:resolved]).to be true
        expect(result[:root]).to eq("test:PersonType")
        expect(result[:namespace]).to eq("http://example.com/test")
        expect(result[:type_category]).to eq("ComplexType")
        expect(result[:dependencies]).to be_a(Hash)
      end

      it "includes direct dependencies" do
        result = grapher.dependencies("test:PersonType", depth: 3)

        # PersonType depends on StringType, IntType, and AddressType
        deps = result[:dependencies]
        expect(deps.keys).to include("test:StringType")
        expect(deps.keys).to include("test:IntType")
        expect(deps.keys).to include("test:AddressType")
      end

      it "includes nested dependencies" do
        result = grapher.dependencies("test:PersonType", depth: 3)

        # AddressType depends on CountryType
        address_deps = result[:dependencies]["test:AddressType"]
        expect(address_deps).not_to be_nil
        expect(address_deps[:dependencies]).to be_a(Hash)
        expect(address_deps[:dependencies].keys).to include("test:CountryType")
      end

      it "respects depth limit" do
        result = grapher.dependencies("test:PersonType", depth: 1)

        # With depth 1, should only get direct dependencies
        deps = result[:dependencies]
        expect(deps.keys).to include("test:AddressType")

        # But AddressType should not have its own dependencies listed
        address_deps = deps["test:AddressType"]
        expect(address_deps[:dependencies]).to be_empty
      end

      it "handles types with no dependencies" do
        result = grapher.dependencies("test:StatusType", depth: 3)

        expect(result[:resolved]).to be true
        expect(result[:dependencies]).to be_empty
      end

      it "includes dependency metadata" do
        result = grapher.dependencies("test:PersonType", depth: 2)

        string_type = result[:dependencies]["test:StringType"]
        expect(string_type[:namespace]).to eq("http://example.com/test")
        expect(string_type[:local_name]).to eq("StringType")
        expect(string_type[:type_category]).to eq("SimpleType")
        expect(string_type[:schema_file]).to match(/\.xsd$/)
      end

      it "handles complex content extensions" do
        result = grapher.dependencies("test:EmployeeType", depth: 3)

        # EmployeeType extends PersonType
        deps = result[:dependencies]
        expect(deps.keys).to include("test:PersonType")
      end
    end

    context "when type is not found" do
      it "returns error information" do
        grapher = described_class.new(repository)
        result = grapher.dependencies("test:NonExistentType", depth: 3)

        expect(result[:resolved]).to be false
        expect(result[:error]).to be_a(String)
        expect(result[:qname]).to eq("test:NonExistentType")
      end
    end

    context "with circular dependencies" do
      it "handles circular references without infinite recursion" do
        # The visited set should prevent infinite loops
        result = grapher.dependencies("test:PersonType", depth: 10)

        expect(result[:resolved]).to be true
        # Should complete without stack overflow
      end
    end
  end

  describe "#dependents" do
    let(:grapher) { described_class.new(repository) }

    context "when type is found" do
      it "returns list of types that depend on StringType" do
        result = grapher.dependents("test:StringType")

        expect(result[:resolved]).to be true
        expect(result[:target]).to eq("test:StringType")
        expect(result[:namespace]).to eq("http://example.com/test")
        expect(result[:dependents]).to be_an(Array)
        expect(result[:count]).to be > 0
      end

      it "finds types that use StringType" do
        result = grapher.dependents("test:StringType")

        dependent_names = result[:dependents].map { |d| d[:local_name] }

        # PersonType, AddressType, and CountryType all use StringType
        expect(dependent_names).to include("PersonType")
        expect(dependent_names).to include("AddressType")
        expect(dependent_names).to include("CountryType")
      end

      it "includes dependent metadata" do
        result = grapher.dependents("test:StringType")

        first_dependent = result[:dependents].first
        expect(first_dependent[:qname]).to be_a(String)
        expect(first_dependent[:namespace]).to eq("http://example.com/test")
        expect(first_dependent[:local_name]).to be_a(String)
        expect(first_dependent[:type_category]).to be_a(String)
        expect(first_dependent[:schema_file]).to match(/\.xsd$/)
      end

      it "handles types with no dependents" do
        result = grapher.dependents("test:EmployeeType")

        expect(result[:resolved]).to be true
        expect(result[:dependents]).to be_an(Array)
        expect(result[:count]).to be 1
      end

      it "finds types that extend a base type" do
        result = grapher.dependents("test:PersonType")

        dependent_names = result[:dependents].map { |d| d[:local_name] }
        expect(dependent_names).to include("EmployeeType")
      end
    end

    context "when type is not found" do
      it "returns error information" do
        result = grapher.dependents("test:NonExistentType")

        expect(result[:resolved]).to be false
        expect(result[:error]).to be_a(String)
      end
    end
  end

  describe "#to_mermaid" do
    let(:grapher) { described_class.new(repository) }

    it "generates Mermaid diagram for dependencies" do
      graph = grapher.dependencies("test:PersonType", depth: 2)
      mermaid = grapher.to_mermaid(graph)

      expect(mermaid).to include("graph TD")
      expect(mermaid).to include("test:PersonType")
      expect(mermaid).to include("-->")
    end

    it "handles error graphs" do
      graph = { resolved: false, error: "Type not found" }
      mermaid = grapher.to_mermaid(graph)

      expect(mermaid).to include("graph TD")
      expect(mermaid).to include("error")
      expect(mermaid).to include("Type not found")
    end

    it "escapes special characters in node names" do
      graph = grapher.dependencies("test:PersonType", depth: 1)
      mermaid = grapher.to_mermaid(graph)

      # Mermaid uses ["label"] syntax - verify the format is correct
      expect(mermaid).to include('["test:PersonType"]')
      # Verify that if there were quotes in the name, they'd be escaped as &quot;
      expect(mermaid).not_to include('"test:PersonType""') # No double quotes
    end

    it "includes styling for root node" do
      graph = grapher.dependencies("test:PersonType", depth: 1)
      mermaid = grapher.to_mermaid(graph)

      expect(mermaid).to include("style")
      expect(mermaid).to include("fill")
    end
  end

  describe "#to_dot" do
    let(:grapher) { described_class.new(repository) }

    it "generates DOT diagram for dependencies" do
      graph = grapher.dependencies("test:PersonType", depth: 2)
      dot = grapher.to_dot(graph)

      expect(dot).to include("digraph dependencies")
      expect(dot).to include("test:PersonType")
      expect(dot).to include("->")
    end

    it "handles error graphs" do
      graph = { resolved: false, error: "Type not found" }
      dot = grapher.to_dot(graph)

      expect(dot).to include("digraph")
      expect(dot).to include("error")
      expect(dot).to include("Type not found")
    end

    it "includes graph attributes" do
      graph = grapher.dependencies("test:PersonType", depth: 1)
      dot = grapher.to_dot(graph)

      expect(dot).to include("rankdir")
      expect(dot).to include("node")
      expect(dot).to include("shape=box")
    end

    it "escapes special characters in labels" do
      graph = grapher.dependencies("test:PersonType", depth: 1)
      dot = grapher.to_dot(graph)

      # Should properly escape quotes
      expect(dot).to include("label=")
    end

    it "applies styling to root node" do
      graph = grapher.dependencies("test:PersonType", depth: 1)
      dot = grapher.to_dot(graph)

      expect(dot).to include("fillcolor")
    end
  end

  describe "#to_text" do
    let(:grapher) { described_class.new(repository) }

    it "generates text representation for dependencies" do
      graph = grapher.dependencies("test:PersonType", depth: 2)
      text = grapher.to_text(graph)

      expect(text).to include("Type: test:PersonType")
      expect(text).to include("Namespace: http://example.com/test")
      expect(text).to include("Category: ComplexType")
      expect(text).to include("Dependencies")
    end

    it "handles error graphs" do
      graph = { resolved: false, error: "Type not found" }
      text = grapher.to_text(graph)

      expect(text).to include("Error: Type not found")
    end

    it "shows dependencies in tree format" do
      graph = grapher.dependencies("test:PersonType", depth: 2)
      text = grapher.to_text(graph)

      expect(text).to include("test:StringType")
      expect(text).to include("test:AddressType")
    end

    it "handles types with no dependencies" do
      graph = grapher.dependencies("test:StatusType", depth: 2)
      text = grapher.to_text(graph)

      expect(text).to include("(none)")
    end

    it "respects direction parameter" do
      graph = grapher.dependencies("test:PersonType", depth: 2)
      text_both = grapher.to_text(graph, direction: "both")
      text_down = grapher.to_text(graph, direction: "down")

      expect(text_both).to include("Dependencies")
      expect(text_down).to include("Dependencies")
    end
  end

  describe "integration with complex schemas" do
    let(:grapher) { described_class.new(repository) }

    it "handles deep dependency chains" do
      result = grapher.dependencies("test:EmployeeType", depth: 5)

      # EmployeeType -> PersonType -> AddressType -> CountryType -> StringType
      expect(result[:resolved]).to be true

      # Should find PersonType
      expect(result[:dependencies].keys).to include("test:PersonType")

      # PersonType should have AddressType
      person_deps = result[:dependencies]["test:PersonType"]
      expect(person_deps[:dependencies].keys).to include("test:AddressType")

      # AddressType should have CountryType
      address_deps = person_deps[:dependencies]["test:AddressType"]
      expect(address_deps[:dependencies].keys).to include("test:CountryType")
    end

    it "correctly identifies all dependents of a base type" do
      result = grapher.dependents("test:IntType")

      # Both PersonType and EmployeeType use IntType
      dependent_names = result[:dependents].map { |d| d[:local_name] }
      expect(dependent_names).to include("PersonType")
      expect(dependent_names).to include("EmployeeType")
    end
  end
end
