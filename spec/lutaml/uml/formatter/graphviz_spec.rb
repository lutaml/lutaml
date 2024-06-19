# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Formatter::Graphviz do
  describe ".format_document" do
    subject(:format_document) do
      described_class.new.format_document(input_document)
    end

    context "when simple aggregation" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(fixtures_path("datamodel/views/AddressProfile.yml"))
      end

      let(:formatted_dot_content) do
        File.read(fixtures_path("generated_dot/AddressProfile.dot"))
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end

    context "when aggregation with inheritance" do
      let(:input_document) do
        Lutaml::Uml::Parsers::Yaml
          .parse(fixtures_path("datamodel/views/AddressClassProfile.yml"))
      end

      let(:formatted_dot_content) do
        File.read(fixtures_path("generated_dot/AddressClassProfile.dot"))
      end

      it "generates the correct relationship graph" do
        expect(format_document).to eq(formatted_dot_content)
      end
    end
  end
end
