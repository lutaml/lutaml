# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/cli"

require_relative "../../../../lib/lutaml/uml_repository"
RSpec.describe Lutaml::Cli::Uml::ExportCommand do
  let(:test_xmi) { File.join(__dir__, "../../../../examples/xmi/basic.xmi") }
  let(:test_lur) do
    path = temp_lur_path(prefix: "export_test")
    repo = cached_xmi_repository(test_xmi)
    repo.export_to_package(path)
    path
  end
  let(:output_file) do
    temp_lur_path(prefix: "export_output").sub(/\.lur$/, ".csv")
  end
  let(:command) { described_class.new(options) }

  after do
    FileUtils.rm_f(test_lur)
    FileUtils.rm_f(output_file)
  end

  describe "#run" do
    context "exporting to JSON" do
      let(:output_json) do
        temp_lur_path(prefix: "export_output").sub(/\.lur$/, ".json")
      end
      let(:options) { { format: "json", output: output_json } }

      after do
        FileUtils.rm_f(output_json)
      end

      it "exports to JSON format", :aggregate_failures do
        expect { command.run(test_lur) }.to output(/Exported to/).to_stdout
        expect(File.exist?(output_json)).to be true
      end
    end

    context "error handling" do
      let(:options) { { format: "csv", output: output_file } }

      it "exports successfully" do
        expect { command.run(test_lur) }.to raise_error(/Unknown format/)
      end
    end

    context "schema realization" do
      let(:schema_lur) do
        path = temp_lur_path(prefix: "schema_export")
        address = Lutaml::Uml::Class.new(
          name: "Address",
          attributes: [
            Lutaml::Uml::TopElementAttribute.new(
              name: "id", type: "String",
              tagged_values: [
                Lutaml::Uml::TaggedValue.new(name: "xmlAttribute", value: "true"),
              ]
            ),
            Lutaml::Uml::TopElementAttribute.new(
              name: "street", type: "String",
              tagged_values: [
                Lutaml::Uml::TaggedValue.new(name: "sequenceNumber", value: "1"),
              ]
            ),
          ],
        )
        document = Lutaml::Uml::Document.new(name: "M", classes: [address])
        Lutaml::UmlRepository::Repository.new(document: document)
          .export_to_package(path)
        path
      end
      let(:schema_output) do
        temp_lur_path(prefix: "schema_output").sub(/\.lur$/, ".xsd")
      end

      after do
        FileUtils.rm_f(schema_lur)
        FileUtils.rm_f(schema_output)
      end

      context "to XSD with --class" do
        let(:options) { { format: "xsd", class: "Address", output: schema_output } }

        it "writes an XSD driven by the tagged values", :aggregate_failures do
          expect { command.run(schema_lur) }.to output(/Exported to/).to_stdout
          xsd = File.read(schema_output)
          expect(xsd).to include('<attribute name="id"')
          expect(xsd).to include('<element name="street"')
        end
      end

      context "without --class" do
        let(:options) { { format: "json-schema", output: schema_output } }

        it "fails asking for a class to realize" do
          expect { command.run(schema_lur) }
            .to raise_error(/--class is required/)
        end
      end
    end
  end
end
