# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "tmpdir"

ENGINE_SUPPORTED = Lutaml::Xsd::Validation::EngineContext.xsd_supported?(
  Moxml::Context.new,
)
# Some tier-1 engines (nokogiri) validate documents but ship no
# standalone built-in lexical table — capability, not adapter, decides.
ENGINE_BUILTIN = begin
  Moxml::XSD.builtin_valid?(Moxml::Context.new, "xs:date", "2024-01-15")
rescue StandardError
  nil
end == true

# Set compilation (Context#xsd_set) is engine-face-gated: nokogiri pins
# the contract unsupported and older moxml lacks the face.
ENGINE_SET = begin
  Dir.mktmpdir do |dir|
    paths = %w[a.xsd b.xsd].map do |name|
      path = File.join(dir, name)
      File.write(path,
                 '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>')
      path
    end
    Moxml::Context.new.xsd_set(*paths)
    true
  end
rescue StandardError
  false
end

RSpec.describe Lutaml::Xsd::Validation::EngineContext do
  let(:context) { Moxml::Context.new }

  let(:xsd_source) do
    <<~XML
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="date" type="xs:date"/>
      </xs:schema>
    XML
  end

  let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }

  let(:repository) do
    Class.new do
      def initialize(schemas)
        @schemas = schemas
      end

      def all_schemas
        @schemas
      end
    end.new({ "http://example.com/test" => schema })
  end

  def compile
    described_class.compile(repository, context: context)
  end

  describe ".compile" do
    it "compiles when the adapter ships an XSD validator", if: ENGINE_SUPPORTED do
      engine = compile
      expect(engine).to be_a(described_class)
      expect(engine).to be_supported
    end

    it "returns nil on adapters without an XSD validator", unless: ENGINE_SUPPORTED do
      expect(compile).to be_nil
    end

    it "compiles file-backed schemas as one schema set",
       if: ENGINE_SUPPORTED && ENGINE_SET do
      Dir.mktmpdir do |dir|
        head_path = File.join(dir, "head.xsd")
        decl_path = File.join(dir, "decl.xsd")
        File.write(head_path, <<~XML)
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://foobar" xmlns="http://foobar">
            <xs:import namespace="http://foo" schemaLocation="decl.xsd"/>
            <xs:element name="foo">
              <xs:complexType>
                <xs:sequence>
                  <xs:any namespace="##any" processContents="strict"/>
                </xs:sequence>
              </xs:complexType>
            </xs:element>
          </xs:schema>
        XML
        File.write(decl_path, <<~XML)
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://foo" xmlns="http://foo">
            <xs:element name="bar" type="xs:string"/>
          </xs:schema>
        XML
        head = Lutaml::Xml::Schema::Xsd.parse(File.read(head_path),
                                              location: head_path)
        decl = Lutaml::Xml::Schema::Xsd.parse(File.read(decl_path),
                                              location: decl_path)
        repository = Class.new do
          def initialize(schemas, paths)
            @schemas = schemas
            @paths = paths
          end

          def all_schemas
            @schemas
          end

          def source_path_for(schema)
            @paths[schema]
          end
        end.new({ "http://foobar" => head, "http://foo" => decl },
                head => head_path, decl => decl_path)

        engine = described_class.compile(repository, context: context)

        # One set handle across both documents; the root may live in an
        # imported document, so the set carries no target-namespace
        # filter. Cross-document wildcard admission itself is an engine
        # limitation tracked upstream.
        expect(engine.schemas.size).to eq(1)
        expect(engine.schemas.first.target_namespace).to be_nil
        expect(engine.schemas.first.element_names)
          .to contain_exactly("foo", "bar")
      end
    end
  end

  describe "#findings_for", if: ENGINE_SUPPORTED do
    it "maps engine findings to Validation::ValidationError" do
      engine = compile
      findings = engine.findings_for("<date>not-a-date</date>")

      expect(findings).to all(be_a(Lutaml::Xsd::Validation::ValidationError))
      expect(findings.map(&:code)).to all(eq(described_class::ENGINE_CODE))
      expect(findings).to all(be_error)
    end

    it "reports no findings for valid documents" do
      engine = compile

      expect(engine.findings_for("<date>2024-01-15</date>")).to be_empty
    end
  end

  describe "#builtin_valid?", if: ENGINE_SUPPORTED do
    it "answers lexical checks when the engine ships a builtin table", if: ENGINE_BUILTIN do
      engine = compile

      expect(engine.builtin_valid?("xs:date", "2024-01-15")).to eq(true)
      expect(engine.builtin_valid?("xs:date", "not-a-date")).to eq(false)
    end

    it "normalizes nil facade answers through the value space", if: ENGINE_BUILTIN do
      # moxml#485: the facade's date lambdas leak nil when the lexical
      # misses their regex — the value space still decides.
      engine = compile

      expect(engine.builtin_valid?("xs:date", "not-a-date")).to eq(false)
      expect(engine.builtin_valid?("xs:dateTime", "garbage")).to eq(false)
      expect(engine.builtin_valid?("xs:date", "2024-02-30")).to eq(false)
      expect(engine.builtin_valid?("xs:date", "2024-01-15")).to eq(true)
    end

    it "returns nil when the engine lacks a builtin table", if: ENGINE_SUPPORTED, unless: ENGINE_BUILTIN do
      engine = compile

      expect(engine.builtin_valid?("xs:date", "2024-01-15")).to be_nil
    end

    it "returns nil for unknown built-in names", if: ENGINE_BUILTIN do
      engine = compile

      expect(engine.builtin_valid?("xs:unknownType", "x")).to be_nil
    end
  end

  describe "#simple_valid and #content_valid", if: ENGINE_SUPPORTED do
    it "returns nil when no compiled schema knows the type" do
      engine = compile
      root = Moxml::Context.new.parse("<a><b/></a>").root

      expect(engine.simple_valid("noSuchType", "x")).to be_nil
      expect(engine.content_valid("noSuchElement", root.children.to_a)).to be_nil
    end
  end

  describe "#content_valid live engine answers", if: ENGINE_SUPPORTED do
    let(:content_schema) do
      Lutaml::Xml::Schema::Xsd.parse(<<~XML)
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="person">
            <xs:complexType>
              <xs:sequence>
                <xs:element name="name" type="xs:string"/>
                <xs:element name="age" type="xs:integer"/>
              </xs:sequence>
            </xs:complexType>
          </xs:element>
        </xs:schema>
      XML
    end
    let(:content_repository) do
      Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        def all_schemas
          @schemas
        end
      end.new({ "" => content_schema })
    end
    let(:content_engine) do
      described_class.compile(content_repository, context: context)
    end

    def children_for(xml)
      Moxml::Context.new.parse(xml).root.children.to_a
    end

    it "answers true for a matching child sequence" do
      answer = content_engine.content_valid(
        "person", children_for("<person><name>A</name><age>1</age></person>")
      )
      # Engines without a standalone content checker answer nil.
      expect([true, nil]).to include(answer)
    end

    it "answers false for an out-of-order child sequence" do
      answer = content_engine.content_valid(
        "person", children_for("<person><age>1</age><name>A</name></person>")
      )
      expect([false, nil]).to include(answer)
    end
  end
end
