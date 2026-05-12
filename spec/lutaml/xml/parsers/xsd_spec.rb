# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Lutaml::Xml::Parsers::Xsd do
  describe ".parse" do
    subject(:result) { described_class.parse(File.new(xsd_path), options) }

    let(:xsd_path) { fixtures_path("schema.xsd") }
    let(:options) { {} }

    it "returns a Schema object" do
      expect(result).to be_a(Lutaml::Xml::Schema::Xsd::Schema)
    end

    describe "parsed content" do
      it "contains both complex types", :aggregate_failures do
        type_names = result.complex_type.map(&:name)
        expect(type_names).to include("Person", "Address")
      end

      it "parses the Person element correctly", :aggregate_failures do
        person = result.complex_type.find { |t| t.name == "Person" }
        expect(person).not_to be_nil
        person_elements = person.sequence.element.map(&:name)
        expect(person_elements).to include("FirstName", "LastName", "Hobby",
                                           "Address")
      end

      it "parses the Address element correctly", :aggregate_failures do
        address = result.complex_type.find { |t| t.name == "Address" }
        expect(address).not_to be_nil
        address_elements = address.sequence.element.map(&:name)
        expect(address_elements).to include("City", "ZIP")
      end

      it "parses top-level element declarations" do
        element_names = result.element.map(&:name)
        expect(element_names).to include("Person")
      end
    end

    describe "option forwarding" do
      let(:options) { { location: "/some/path" } }

      it "passes location option to the underlying parser" do
        allow(Lutaml::Xml::Schema::Xsd).to receive(:parse).and_call_original

        result

        expect(Lutaml::Xml::Schema::Xsd).to have_received(:parse).with(
          anything,
          hash_including(location: "/some/path"),
        )
      end
    end

    describe "error handling" do
      let(:invalid_file) do
        file = Tempfile.new(%w[invalid .xsd])
        file.write("this is not xml at all")
        file.close
        file
      end

      after do
        invalid_file.unlink
      end

      it "raises an error for invalid XSD content" do
        expect { described_class.parse(File.new(invalid_file.path)) }
          .to raise_error(StandardError)
      end
    end
  end
end
