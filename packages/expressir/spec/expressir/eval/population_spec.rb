# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "expressir/eval"

# TODO.instance/02: the population-scale rule engine — WHERE rules
# scoped over entities and their subtypes via typing, UNIQUE rules
# (9.2.2.1) across the population, and global rules (9.4) with the
# FOR entities bound to their instance aggregates.
RSpec.describe Expressir::Eval::Population do
  let(:schema) do
    Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
      SCHEMA pop_demo;
      ENTITY base ABSTRACT SUPERTYPE;
        code : INTEGER;
      END_ENTITY;
      ENTITY material SUBTYPE OF (base);
        UNIQUE u1 : code;
        WHERE nonneg : code >= 0;
      END_ENTITY;
      ENTITY special SUBTYPE OF (material);
      END_ENTITY;
      ENTITY document SUBTYPE OF (base);
        text : STRING;
      END_ENTITY;
      ENTITY blob;
        n : INTEGER;
      END_ENTITY;
      RULE material_codes_nonneg FOR (material);
        WHERE
          ok : SIZEOF(QUERY(m <* material | m.code < 0)) = 0;
      END_RULE;
      END_SCHEMA;
    EXP
  end

  def population_for(body)
    Expressir::P21::Parser.parse(<<~P21)
      ISO-10303-21;
      HEADER;
      FILE_NAME('demo.stp','2026-10-21T00:00:00',('a'),('o'),'p','s','z');
      FILE_SCHEMA(('pop_demo'));
      ENDSEC;
      DATA;
      #{body}
      ENDSEC;
      END-ISO-10303-21;
    P21
  end

  def findings_for(body)
    described_class.check(schema, population_for(body))
  end

  it "passes a conforming population with zero findings" do
    findings = findings_for(<<~P21.chomp)
      #1=MATERIAL(5);
      #2=MATERIAL(7);
      #3=DOCUMENT('spec');
      #4=BLOB(-2);
    P21
    expect(findings).to be_empty
  end

  it "applies an entity WHERE rule to a subtype instance (9.2.1)" do
    findings = findings_for("#5=SPECIAL(-1);")
    where = findings.find { |finding| finding.kind == :where }
    expect(where.rule_id).to eq("nonneg")
    expect(where.instance).to eq("#5")
    expect(where.message).to include("9.4")
  end

  it "finds a UNIQUE violation across subtypes regardless of order (9.2.2.1)" do
    findings = findings_for(<<~P21.chomp)
      #1=MATERIAL(9);
      #2=SPECIAL(9);
    P21
    unique = findings.find { |finding| finding.kind == :unique }
    expect(unique.rule_id).to eq("u1")
    expect(unique.message).to include("duplicates #1")
    expect(unique.message).to include("9.2.2.1")
  end

  it "accepts distinct codes under the same UNIQUE rule" do
    findings = findings_for(<<~P21.chomp)
      #1=MATERIAL(9);
      #2=SPECIAL(10);
    P21
    expect(findings).to be_empty
  end

  it "flags an unknown attribute in a UNIQUE rule" do
    schema = Expressir::Express::Parser.from_exp(<<~EXP).schemas.first
      SCHEMA bad_unique;
      ENTITY thing;
        n : INTEGER;
        UNIQUE u1 : missing;
      END_ENTITY;
      END_SCHEMA;
    EXP
    findings = described_class.check(schema, population_for("#1=THING(1);"))
    expect(findings.map(&:kind)).to eq([:unique])
    expect(findings.first.message).to include("outside 'thing'")
  end

  it "evaluates a global rule once over the FOR aggregate (9.4)" do
    findings = findings_for(<<~P21.chomp)
      #1=MATERIAL(5);
      #2=SPECIAL(-1);
    P21
    global = findings.find { |finding| finding.kind == :global }
    expect(global.rule_id).to eq("material_codes_nonneg")
    expect(global.instance).to be_nil
    expect(global.message).to include("9.4")
  end

  it "keeps a global rule clean when the FOR set satisfies it" do
    findings = findings_for(<<~P21.chomp)
      #1=MATERIAL(5);
      #2=SPECIAL(6);
    P21
    expect(findings).to be_empty
  end

  it "is deterministic for the same population" do
    body = <<~P21.chomp
      #1=MATERIAL(5);
      #2=SPECIAL(-1);
      #3=MATERIAL(9);
    P21
    first = described_class.check(schema, population_for(body))
    second = described_class.check(schema, population_for(body))
    expect(second).to eq(first)
  end

  describe "Annex H at engine level" do
    let(:annex_h_schema) do
      Expressir::Express::Parser.from_file(
        Expressir.root_path.join("spec/fixtures/p21/annex_h_schema.exp"),
      ).schemas.first
    end

    it "runs the engine checks clean over the Annex H population" do
      population = Expressir::P21::Parser.parse(
        File.read(Expressir.root_path.join("spec/fixtures/p21/annex_h.p21")),
      )
      findings = described_class.check(
        annex_h_schema, population,
        short_names: { "CPT" => "cartesian_point", "VX" => "vertex",
                       "ED" => "edge",
                       "ED_STRC" => "edge_logical_structure",
                       "ED_LOOP" => "edge_loop" }
      )
      expect(findings).to be_empty
    end
  end
end
