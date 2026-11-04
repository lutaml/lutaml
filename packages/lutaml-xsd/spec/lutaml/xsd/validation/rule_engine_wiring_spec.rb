# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/validation/validator"

RSpec.describe "rule engine wiring" do
  let(:xsd_source) do
    <<~XSD
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
    XSD
  end

  # Registers the schema in the global processed-schema cache that
  # SchemaRepository#all_schemas reads.
  let!(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }

  # Real SchemaRepository subclass with an explicit schema source (package
  # loading populates the same shape).
  let(:repository) do
    Class.new(Lutaml::Xsd::SchemaRepository) do
      def initialize(schemas)
        super()
        @fixture_schemas = schemas
      end

      def all_schemas
        @fixture_schemas
      end
    end.new({ "" => schema })
  end
  let(:config) do
    {
      "validation" => {
        "features" => { "engine_validation" => false },
      },
    }
  end
  let(:validator) do
    Lutaml::Xsd::Validation::Validator.new(repository, config: config)
  end

  it "reports rule findings for a content-model violation without the engine" do
    result = validator.validate(
      "<person><age>30</age><name>A</name></person>",
    )

    expect(result.valid?).to be(false)
    codes = result.errors.map(&:code)
    expect(codes).to include("unexpected_element_in_sequence")
  end

  it "reports missing required content without the engine" do
    result = validator.validate("<person><name>A</name></person>")

    expect(result.valid?).to be(false)
    expect(result.errors).not_to be_empty
  end

  it "accepts a valid instance without the engine" do
    result = validator.validate(
      "<person><name>A</name><age>30</age></person>",
    )

    expect(result.valid?).to be(true)
  end

  it "reports a root element no schema in the package declares" do
    result = validator.validate("<unknown><x/></unknown>")

    expect(result.valid?).to be(false)
    codes = result.errors.map(&:code)
    expect(codes).to include("element_not_allowed")
  end
end
