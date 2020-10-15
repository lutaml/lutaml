# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Express::Parsers::Exp do
  describe ".parse" do
    subject(:parse) { described_class.parse(content) }

    context "when simple diagram without attributes" do
      let(:content) do
        File.new(fixtures_path("test.exp"))
      end

      it "creates Expressir::Model::Repository object from supplied exp file" do
        expect(parse).to be_instance_of(Expressir::Model::Repository)
      end

      it "correctly reads schema attributes" do
        expect(parse.shecmas.first).to(eq('test'))
        expect(parse.shecmas.first).to(eq('test'))
        expect(parse.schemas.first.entities.map(&:id))
          .to(eq(["a3m_data_quality_criteria_representation",
                  "a3m_data_quality_criterion",
                  "a3m_data_quality_criterion_specific_applied_value",
                  "a3m_data_quality_target_accuracy_association",
                  "a3m_detailed_report_request",
                  "a3m_summary_report_request_with_representative_value"]))
      end
    end
  end
end
