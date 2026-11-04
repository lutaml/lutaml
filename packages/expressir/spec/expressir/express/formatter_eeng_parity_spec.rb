# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"

# Regression ports of the Express Engine bug corpus
# (spec/fixtures/eeng/issues) — the formatter behavior eeng settled
# on after each bug, anchored by the old-vs-new shtolo outputs
# recorded in bug39.
RSpec.describe Expressir::Express::Formatter do # eeng parity (bug39/bug40 corpus)
  let(:source) do
    <<~EXP
      SCHEMA s;
      ENTITY Additive_laminate_text_component
      SUBTYPE OF (Generic_laminate_text_component);
      stratum_feature_implementation : SET [1:?] OF Stratum_feature;
      WHERE
      WR1: SIZEOF(QUERY(sf <* stratum_feature_implementation | sf.resident_stratum :<>: stratum_feature_implementation[1].resident_stratum)) = 0;
      END_ENTITY;
      END_SCHEMA;
    EXP
  end

  def formatted
    file = Tempfile.new(%w[eeng-parity .exp])
    file.write(source)
    file.close
    begin
      model = Expressir::Express::Parser.from_file(file.path)
      described_class.format(model.schemas.first)
    ensure
      file.unlink
    end
  end

  it "bug39: emits no redundant parentheses in QUERY or WHERE output" do
    expect(formatted).to eq(<<~EXP.chomp)
      SCHEMA s;

      ENTITY Additive_laminate_text_component
        SUBTYPE OF (Generic_laminate_text_component);
        stratum_feature_implementation : SET [1:?] OF Stratum_feature;
      WHERE
        WR1: SIZEOF(QUERY(sf <* stratum_feature_implementation | sf.resident_stratum :<>: stratum_feature_implementation[1].resident_stratum)) = 0;
      END_ENTITY;

      END_SCHEMA;
    EXP
  end

  it "bug39 invariants: the exact wrapping patterns old shtolo emitted are absent" do
    out = formatted
    aggregate_failures do
      # old shtolo / stepcode exppp wrapped the QUERY body: "| (TRUE )"
      expect(out).not_to include("| (")
      # ... and wrapped the whole rule expression: "wr1: ( SIZEOF"
      expect(out).not_to match(/WR1:\s*\(/i)
      # lowercased labels were also part of the old output
      expect(out).to include("WR1:")
    end
  end

  it "bug40: pretty expression output keeps the source expression shape" do
    # bug40 tracked the same QUERY expression for pretty output; the
    # new-shtolo text is the accepted form.
    expect(formatted).to include(
      "WR1: SIZEOF(QUERY(sf <* stratum_feature_implementation | sf.resident_stratum :<>: stratum_feature_implementation[1].resident_stratum)) = 0;",
    )
  end
end
