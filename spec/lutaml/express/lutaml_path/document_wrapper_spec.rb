# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Express::LutamlPath::DocumentWrapper do
  describe ".parse" do
    subject(:lutaml_path) { described_class.new(repository) }
    subject(:serialized_document) do
      lutaml_path.serialized_document
    end

    context "when simple diagram without attributes" do
      let(:repository) do
        Lutaml::Express::Parsers::Exp.parse(File.new(fixtures_path("test.exp")))
      end
      let(:schema) { "annotated_3d_model_data_quality_criteria_schema" }
      let(:schema_remark) { File.read(fixtures_path("schema_remark.txt")) }
      let(:entities_names) do
        %w[
          a3m_data_quality_criteria_representation
          a3m_data_quality_criterion
          a3m_data_quality_criterion_specific_applied_value
          a3m_data_quality_target_accuracy_association
          a3m_detailed_report_request
          a3m_summary_report_request_with_representative_value
        ]
      end
      let(:formatted_repository) { File.read(fixtures_path("test_formatted.exp")) }
      let(:formatted_entity_1) { File.read(fixtures_path("test_formatted_entities_1.exp")) }
      let(:formatted_entity_2) { File.read(fixtures_path("test_formatted_entities_2.exp")) }

      it "serializes repository attributes" do
        expect(serialized_document.keys).to(eq(["schemas", schema]))
        expect(serialized_document["schemas"]
                .map { |n| n["id"] })
          .to(eq([schema]))
        expect(serialized_document["schemas"].first["remarks"])
          .to(eq([schema_remark.strip]))
      end

      it "merges source code into all schemas and their entities" do
        expect(serialized_document["schemas"].first["sourcecode"])
          .to(eq(formatted_repository))
        expect(serialized_document["schemas"].first["entities"].first["sourcecode"])
          .to(eq(formatted_entity_1))
        expect(serialized_document["schemas"].first["entities"][1]["sourcecode"])
          .to(eq(formatted_entity_2))
      end

      it "correctly finds elements by structure" do
        expect(serialized_document["schemas"].first["entities"]
                .map { |n| n["id"] }).to(eq(entities_names))
      end
    end
  end
end
