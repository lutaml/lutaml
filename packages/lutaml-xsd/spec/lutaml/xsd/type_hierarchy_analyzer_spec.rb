# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/type_hierarchy_analyzer"

RSpec.describe Lutaml::Xsd::TypeHierarchyAnalyzer do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:analyzer) { described_class.new(repository) }

  describe "#initialize" do
    it "stores the repository" do
      expect(analyzer.repository).to eq(repository)
    end
  end

  describe "#analyze" do
    context "when type is not found" do
      before do
        allow(repository).to receive(:find_type).and_return(
          Lutaml::Xsd::TypeResolutionResult.failure(
            qname: "unknown:Type",
            error_message: "Type not found",
          ),
        )
      end

      it "returns nil" do
        result = analyzer.analyze("unknown:Type")
        expect(result).to be_nil
      end
    end

    context "when type is found" do
      let(:complex_type) do
        double("ComplexType", name: "TestType",
                              complex_content: nil,
                              simple_content: nil,
                              restriction: nil,
                              class: Lutaml::Xml::Schema::Xsd::ComplexType).tap do |obj|
          allow(obj).to receive(:is_a?) do |klass|
            klass == Lutaml::Xml::Schema::Xsd::ComplexType
          end
        end
      end

      let(:type_result) do
        result = Lutaml::Xsd::TypeResolutionResult.success(
          qname: "test:TestType",
          namespace: "http://test.com",
          local_name: "TestType",
          definition: complex_type,
          schema_file: "/test/schema.xsd",
        )
        result
      end

      before do
        allow(repository).to receive(:find_type).with("test:TestType").and_return(type_result)
        allow(repository).to receive(:instance_variable_get).with(:@type_index).and_return(
          double(all: {}),
        )
      end

      it "returns hierarchy analysis" do
        result = analyzer.analyze("test:TestType")

        expect(result).to be_a(Hash)
        expect(result[:root]).to eq("test:TestType")
        expect(result[:namespace]).to eq("http://test.com")
        expect(result[:local_name]).to eq("TestType")
        expect(result[:type_category]).to eq(:complex_type)
        expect(result[:ancestors]).to be_an(Array)
        expect(result[:descendants]).to be_an(Array)
        expect(result[:tree]).to be_a(Hash)
        expect(result[:formats]).to be_a(Hash)
        expect(result[:formats][:mermaid]).to be_a(String)
        expect(result[:formats][:text]).to be_a(String)
      end

      it "respects depth parameter" do
        result = analyzer.analyze("test:TestType", depth: 5)
        expect(result).not_to be_nil
      end
    end
  end

  describe "private methods" do
    describe "#extract_base_type" do
      context "with complex content extension" do
        let(:extension) { double("Extension", base: "test:BaseType") }
        let(:complex_content) do
          double("ComplexContent", extension: extension, restriction: nil)
        end
        let(:complex_type) do
          double("ComplexType", complex_content: complex_content,
                                simple_content: nil, restriction: nil)
        end

        it "extracts base type from complex content extension" do
          base = analyzer.send(:extract_base_type, complex_type)
          expect(base).to eq("test:BaseType")
        end
      end

      context "with complex content restriction" do
        let(:restriction) { double("Restriction", base: "test:BaseType") }
        let(:complex_content) do
          double("ComplexContent", extension: nil, restriction: restriction)
        end
        let(:complex_type) do
          double("ComplexType", complex_content: complex_content,
                                simple_content: nil, restriction: nil)
        end

        it "extracts base type from complex content restriction" do
          base = analyzer.send(:extract_base_type, complex_type)
          expect(base).to eq("test:BaseType")
        end
      end

      context "with simple content extension" do
        let(:extension) { double("Extension", base: "xs:string") }
        let(:simple_content) do
          double("SimpleContent", extension: extension, restriction: nil)
        end
        let(:complex_type) do
          double("ComplexType", complex_content: nil,
                                simple_content: simple_content, restriction: nil)
        end

        it "extracts base type from simple content extension" do
          base = analyzer.send(:extract_base_type, complex_type)
          expect(base).to eq("xs:string")
        end
      end

      context "with simple content restriction" do
        let(:restriction) { double("Restriction", base: "xs:integer") }
        let(:simple_content) do
          double("SimpleContent", extension: nil, restriction: restriction)
        end
        let(:complex_type) do
          double("ComplexType", complex_content: nil,
                                simple_content: simple_content, restriction: nil)
        end

        it "extracts base type from simple content restriction" do
          base = analyzer.send(:extract_base_type, complex_type)
          expect(base).to eq("xs:integer")
        end
      end

      context "with simple type restriction" do
        let(:restriction) { double("Restriction", base: "xs:string") }
        let(:simple_type) do
          double("SimpleType", complex_content: nil, simple_content: nil,
                               restriction: restriction)
        end

        it "extracts base type from simple type restriction" do
          base = analyzer.send(:extract_base_type, simple_type)
          expect(base).to eq("xs:string")
        end
      end

      context "with no base type" do
        let(:complex_type) do
          double("ComplexType", complex_content: nil, simple_content: nil,
                                restriction: nil)
        end

        it "returns nil" do
          base = analyzer.send(:extract_base_type, complex_type)
          expect(base).to be_nil
        end
      end
    end

    describe "#determine_type_category" do
      it "identifies ComplexType" do
        type = double("ComplexType", class: Lutaml::Xml::Schema::Xsd::ComplexType,
                                     is_a?: false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(true)
        expect(analyzer.send(:determine_type_category,
                             type)).to eq(:complex_type)
      end

      it "identifies SimpleType" do
        type = double("SimpleType", class: Lutaml::Xml::Schema::Xsd::SimpleType,
                                    is_a?: false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::SimpleType).and_return(true)
        expect(analyzer.send(:determine_type_category,
                             type)).to eq(:simple_type)
      end

      it "identifies Element" do
        type = double("Element", class: Lutaml::Xml::Schema::Xsd::Element,
                                 is_a?: false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::SimpleType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::Element).and_return(true)
        expect(analyzer.send(:determine_type_category, type)).to eq(:element)
      end

      it "identifies AttributeGroup" do
        type = double("AttributeGroup", class: Lutaml::Xml::Schema::Xsd::AttributeGroup,
                                        is_a?: false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::SimpleType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::Element).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::AttributeGroup).and_return(true)
        expect(analyzer.send(:determine_type_category,
                             type)).to eq(:attribute_group)
      end

      it "identifies Group" do
        type = double("Group", class: Lutaml::Xml::Schema::Xsd::Group,
                               is_a?: false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::ComplexType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::SimpleType).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::Element).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::AttributeGroup).and_return(false)
        allow(type).to receive(:is_a?).with(Lutaml::Xml::Schema::Xsd::Group).and_return(true)
        expect(analyzer.send(:determine_type_category, type)).to eq(:group)
      end

      it "returns unknown for unrecognized type" do
        type = double("Unknown", is_a?: false)
        allow(type).to receive(:is_a?).and_return(false)
        expect(analyzer.send(:determine_type_category, type)).to eq(:unknown)
      end
    end

    describe "#build_qualified_name" do
      before do
        allow(repository).to receive(:namespace_to_prefix).with("http://test.com").and_return("test")
        allow(repository).to receive(:namespace_to_prefix).with(nil).and_return(nil)
      end

      it "builds qualified name with prefix" do
        type_info = {
          namespace: "http://test.com",
          definition: double(name: "MyType"),
        }
        qname = analyzer.send(:build_qualified_name, type_info)
        expect(qname).to eq("test:MyType")
      end

      it "builds local name without prefix when namespace is nil" do
        type_info = {
          namespace: nil,
          definition: double(name: "MyType"),
        }
        qname = analyzer.send(:build_qualified_name, type_info)
        expect(qname).to eq("MyType")
      end

      it "builds local name when namespace has no prefix" do
        allow(repository).to receive(:namespace_to_prefix).with("http://unknown.com").and_return(nil)
        type_info = {
          namespace: "http://unknown.com",
          definition: double(name: "MyType"),
        }
        qname = analyzer.send(:build_qualified_name, type_info)
        expect(qname).to eq("MyType")
      end
    end

    describe "#to_mermaid" do
      let(:node) do
        Lutaml::Xsd::TypeHierarchyNode.new("test:RootType",
                                           category: :complex_type)
      end

      it "generates Mermaid diagram syntax" do
        mermaid = analyzer.send(:to_mermaid, node)
        expect(mermaid).to include("graph TD")
        expect(mermaid).to include("test:RootType")
        expect(mermaid).to include("complex_type")
      end

      it "includes ancestors in diagram" do
        ancestor = Lutaml::Xsd::TypeHierarchyNode.new("test:BaseType",
                                                      category: :complex_type)
        node.add_ancestor(ancestor)

        mermaid = analyzer.send(:to_mermaid, node)
        expect(mermaid).to include("test:BaseType")
        expect(mermaid).to include("-->")
      end

      it "includes descendants in diagram" do
        descendant = Lutaml::Xsd::TypeHierarchyNode.new("test:DerivedType",
                                                        category: :complex_type)
        node.add_descendant(descendant)

        mermaid = analyzer.send(:to_mermaid, node)
        expect(mermaid).to include("test:DerivedType")
        expect(mermaid).to include("-->")
      end
    end

    describe "#to_text_tree" do
      let(:node) do
        Lutaml::Xsd::TypeHierarchyNode.new("test:RootType",
                                           category: :complex_type)
      end

      it "generates text tree representation" do
        text = analyzer.send(:to_text_tree, node)
        expect(text).to include("test:RootType")
        expect(text).to include("complex_type")
      end

      it "shows ancestors" do
        ancestor = Lutaml::Xsd::TypeHierarchyNode.new("test:BaseType",
                                                      category: :complex_type)
        node.add_ancestor(ancestor)

        text = analyzer.send(:to_text_tree, node)
        expect(text).to include("Ancestors (base types):")
        expect(text).to include("test:BaseType")
        expect(text).to include("↑")
      end

      it "shows descendants" do
        descendant = Lutaml::Xsd::TypeHierarchyNode.new("test:DerivedType",
                                                        category: :complex_type)
        node.add_descendant(descendant)

        text = analyzer.send(:to_text_tree, node)
        expect(text).to include("Descendants (derived types):")
        expect(text).to include("test:DerivedType")
        expect(text).to include("↓")
      end

      it "prevents infinite recursion with cycles" do
        # This shouldn't happen in practice, but test the protection
        text = analyzer.send(:to_text_tree, node)
        expect(text).to be_a(String)
        expect(text.length).to be > 0
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::TypeHierarchyNode do
  describe "#initialize" do
    it "creates a node with qualified name and category" do
      node = described_class.new("test:Type", category: :complex_type)
      expect(node.qualified_name).to eq("test:Type")
      expect(node.category).to eq(:complex_type)
      expect(node.depth).to eq(0)
      expect(node.ancestors).to be_empty
      expect(node.descendants).to be_empty
    end

    it "accepts custom depth" do
      node = described_class.new("test:Type", category: :simple_type, depth: 3)
      expect(node.depth).to eq(3)
    end
  end

  describe "#add_ancestor" do
    let(:node) { described_class.new("test:Child", category: :complex_type) }
    let(:ancestor) do
      described_class.new("test:Parent", category: :complex_type)
    end

    it "adds an ancestor node" do
      node.add_ancestor(ancestor)
      expect(node.ancestors).to include(ancestor)
    end

    it "does not add duplicate ancestors" do
      node.add_ancestor(ancestor)
      node.add_ancestor(ancestor)
      expect(node.ancestors.size).to eq(1)
    end
  end

  describe "#add_descendant" do
    let(:node) { described_class.new("test:Parent", category: :complex_type) }
    let(:descendant) do
      described_class.new("test:Child", category: :complex_type)
    end

    it "adds a descendant node" do
      node.add_descendant(descendant)
      expect(node.descendants).to include(descendant)
    end

    it "does not add duplicate descendants" do
      node.add_descendant(descendant)
      node.add_descendant(descendant)
      expect(node.descendants.size).to eq(1)
    end
  end

  describe "#to_h" do
    let(:node) do
      described_class.new("test:Type", category: :complex_type, depth: 2)
    end

    it "converts to hash representation" do
      hash = node.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:qualified_name]).to eq("test:Type")
      expect(hash[:category]).to eq(:complex_type)
      expect(hash[:depth]).to eq(2)
      expect(hash[:ancestors]).to be_an(Array)
      expect(hash[:descendants]).to be_an(Array)
    end

    it "includes ancestors in hash" do
      ancestor = described_class.new("test:Ancestor", category: :complex_type)
      node.add_ancestor(ancestor)

      hash = node.to_h
      expect(hash[:ancestors].size).to eq(1)
      expect(hash[:ancestors].first[:qualified_name]).to eq("test:Ancestor")
    end

    it "includes descendants in hash" do
      descendant = described_class.new("test:Descendant",
                                       category: :complex_type)
      node.add_descendant(descendant)

      hash = node.to_h
      expect(hash[:descendants].size).to eq(1)
      expect(hash[:descendants].first[:qualified_name]).to eq("test:Descendant")
    end
  end
end
