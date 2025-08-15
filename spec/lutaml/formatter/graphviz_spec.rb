# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Formatter::Graphviz do
  describe ".format_document" do
    subject(:format_document) do
      described_class.new.format_document(input_document)
    end

    context "when parsing `uml/document.yml`" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(fixtures_path("uml/document.yml"))
      end

      let(:formatted_dot_content) do
        File.read(fixtures_path("generated_dot/document.dot"))
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end

    context "when parsing `uml/document_with_fidelity.yml`" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(fixtures_path("uml/document_with_fidelity.yml"))
      end

      let(:formatted_dot_content) do
        File.read(fixtures_path("generated_dot/document_with_fidelity.dot"))
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end

    context "when parsing `uml/address_profile_with_associations.yml`" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(fixtures_path("uml/address_profile_with_associations.yml"))
      end

      let(:formatted_dot_content) do
        File.read(
          fixtures_path("generated_dot/address_profile_with_associations.dot"),
        )
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end

    context "when parsing `uml/address_class_profile_with_associations.yml`" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(
            fixtures_path("uml/address_class_profile_with_associations.yml"),
          )
      end

      let(:formatted_dot_content) do
        File.read(
          fixtures_path(
            "generated_dot/address_class_profile_with_associations.dot",
          ),
        )
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end
  end
end
