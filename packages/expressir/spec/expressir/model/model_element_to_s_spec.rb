require "spec_helper"

RSpec.describe Expressir::Model::ModelElement do
  describe "#to_s" do
    let(:source) do
      <<~EXPRESS
        SCHEMA to_s_schema;

          FUNCTION probe(input : INTEGER) : LOGICAL;
            LOCAL
              total : INTEGER := 0;
            END_LOCAL;
            -- LEADING remark
            total := total + input;
            RETURN (TRUE);
          END_FUNCTION;

        END_SCHEMA;
      EXPRESS
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:schema) { repo.schemas.first }

    it "matches #format, the documented default" do
      expect(schema.to_s).to eq(schema.format)
    end

    it "keeps remarks, so interpolation renders full EXPRESS" do
      expect(schema.to_s).to include("-- LEADING remark")
      # Interpolation is the behavior under test here, so it stays literal
      # rather than being rewritten to the #to_s call above.
      interpolated = "#{schema}" # rubocop:disable Style/RedundantInterpolation
      expect(interpolated).to include("-- LEADING remark")
    end

    it "leaves remark-free output to an explicit #format call" do
      expect(schema.format(no_remarks: true)).not_to include("-- LEADING remark")
    end
  end
end
