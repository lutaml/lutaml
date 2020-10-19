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
      let(:schema) { 'annotated_3d_model_data_quality_criteria_schema' }
      let(:entities_names) do
        %w[
          a3m_data_quality_criteria_representation
          a3m_data_quality_criterion
          a3m_data_quality_criterion_specific_applied_value
          a3m_data_quality_target_accuracy_association
          a3m_detailed_report_request
          a3m_summary_report_request_with_representative_value]
      end

      it "serializes repository attributes" do
        expect(serialized_document.keys).to(eq([schema]))
        expect(serialized_document[schema]).to(include(*entities_names))
      end

      it "correctly finds elements by jmespath expression" do
        expect(lutaml_path.find("#{schema}.#{entities_names.first}.id")).to(eq('a3m_data_quality_criteria_representation'))
      end
    end
  end
end
