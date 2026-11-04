# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::Parser do
  describe ".from_exp with UTF-8 BOM" do
    let(:bom) { String.new("\xEF\xBB\xBF", encoding: "UTF-8") }
    let(:schema_source) do
      <<~EXP
        SCHEMA bom_test_schema;
        ENTITY test_entity;
          attr : STRING;
        END_ENTITY;
        END_SCHEMA;
      EXP
    end

    it "parses a file with a UTF-8 BOM prefix" do
      exp_file = described_class.from_exp(bom + schema_source)
      expect(exp_file.schemas.first.id).to eq("bom_test_schema")
    end

    it "parses a file without a BOM (regression check)" do
      exp_file = described_class.from_exp(schema_source)
      expect(exp_file.schemas.first.id).to eq("bom_test_schema")
    end

    it "preserves source text after BOM stripping" do
      exp_file = described_class.from_exp(
        bom + schema_source, include_source: true
      )
      schema = exp_file.schemas.first
      expect(schema.source).not_to be_nil
      expect(schema.source).not_to include("\xEF")
    end
  end
end
