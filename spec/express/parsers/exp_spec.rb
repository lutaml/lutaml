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

      it "correctly reads schema attributes", :aggregate_failures do
        expect(parse.schemas.first.id)
          .to(eq("annotated_3d_model_data_quality_criteria_schema"))
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

  describe ".parse_cache" do
    context "when exp cache yaml file has an old version" do
      let(:input_path) do
        fixtures_path("test-generic.exp_cached_old_version.yaml")
      end
      let(:exp_schema_path) { fixtures_path("test-generic.exp") }

      before do
        repository = Expressir::Express::Parser.from_file(exp_schema_path)
        Expressir::Express::Cache.to_file(input_path, repository,
                                          test_overwrite_version: "0.2.21")
      end

      it "raises Expressir::Error" do
        expect do
          described_class.parse_cache(input_path)
        end.to raise_error(Expressir::Express::Error::CacheVersionMismatchError)
      end
    end

    context "when exp cache yaml file is valid" do
      let(:input_path) { fixtures_path("test-generic.exp_cached_valid.yaml") }
      let(:exp_schema_path) { fixtures_path("test-generic.exp") }

      before do
        repository = Expressir::Express::Parser.from_file(exp_schema_path)
        Expressir::Express::Cache.to_file(input_path, repository)
      end

      it "returns a Cache from cache" do
        result = described_class.parse_cache(input_path)
        expect(result).to be_instance_of(Expressir::Model::Cache)
      end
    end
  end
end
