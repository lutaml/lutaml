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
        Expressir::ExpressExp::Parser.from_files([File.new(fixtures_path("test.exp"))])
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

      it "serializes repository attributes" do
        expect(serialized_document
                .map { |n| n["id"] })
          .to(eq([schema]))
        expect(serialized_document.first["remarks"])
          .to(eq([schema_remark.strip]))
      end

      it "merges source code into all schemas and their entities" do
        expect(serialized_document.first["source"].length)
          .to(be_positive)
        expect(serialized_document.first["entities"].first["source"].length)
          .to(be_positive)
        expect(serialized_document.first["entities"][1]["source"].length)
          .to(be_positive)
      end

      it "correctly finds elements by structure" do
        expect(serialized_document.first["entities"]
                .map { |n| n["id"] }).to(eq(entities_names))
      end
    end
  end
end
