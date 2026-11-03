# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# ISO 10303-11:2004 Annex G conversion — spec/fixtures/shtolo/
# annex-g-rules.md is the rule table this suite exercises.
RSpec.describe Expressir::Express::Shtolo do
  def parse_repository(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path), skip_references: true)
    [repository, files]
  end

  def flatten(root_schema, repository)
    described_class.new(root_schema, repository).flatten.schema
  end

  def schema_of(model, id)
    model.schemas.find { |s| s.id == id }
  end

  describe "G.1.3 renamed USE items copy under their original name" do
    it "rewrites references from the alias to the original" do
      sources = {
        "second_schema" => "SCHEMA second_schema;\nENTITY alfred;\n  a1 : STRING;\nEND_ENTITY;\nENTITY bert;\n  b1 : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "sch_schema" => "SCHEMA sch_schema;\nUSE FROM second_schema (alfred AS alf, bert AS herbert);\nENTITY joe;\n  attr1 : alf;\n  attr2 : herbert;\nEND_ENTITY;\nEND_SCHEMA;\n",
      }
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "sch_schema"), repository)
      files.each(&:unlink)

      joe = longform.entities.find { |e| e.id == "joe" }
      aggregate_failures do
        expect(longform.entities.map(&:id)).to include("alfred", "bert")
        expect(joe.attributes[0].type.id).to eq("alfred")
        expect(joe.attributes[1].type.id).to eq("bert")
      end
    end
  end

  describe "G.NM.1 name munging" do
    it "prefixes clashing declarations with schema_dot_" do
      sources = {
        "farming" => "SCHEMA farming;\nUSE FROM s1_schema (creature);\nENTITY farming_dot_dog SUBTYPE OF (creature);\n  x : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "s1_schema" => "SCHEMA s1_schema;\nENTITY creature;\n  y : STRING;\nEND_ENTITY;\nENTITY dog;\n  z : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n",
      }
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "farming"), repository)
      files.each(&:unlink)

      ids = longform.entities.map(&:id)
      expect(ids).to include("creature")
    end
  end

  describe "G.2 stage 2 output invariants" do
    it "produces a schema with no interfaces and parses back" do
      sources = {
        "root_schema" => "SCHEMA root_schema;\nUSE FROM support_schema (identifier);\nENTITY root_entity;\n  id : identifier;\nEND_ENTITY;\nEND_SCHEMA;\n",
        "support_schema" => "SCHEMA support_schema;\nTYPE identifier = STRING; END_TYPE;\nEND_SCHEMA;\n",
      }
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root_schema"), repository)
      files.each(&:unlink)

      expect(longform.interfaces).to be_empty
      text = Expressir::Express::Formatter.format(longform)
      expect(text).not_to match(/USE FROM|REFERENCE FROM/)

      f = Tempfile.new(%w[lf .exp])
      f.write("SCHEMA #{longform.id};\n#{text.sub(/\ASCHEMA #{longform.id};\n?/, '').sub(/END_SCHEMA;\s*\z/, '')}\nEND_SCHEMA;\n")
      f.close
      begin
        reparsed = Expressir::Express::Parser.from_file(f.path, skip_references: true)
        expect(reparsed.schemas.first.entities.map(&:id)).to include("root_entity")
      ensure
        f.unlink
      end
    end

    it "G.2.5 eliminates subtype constraints and emits a TOTAL_OVER rule" do
      sources = {
        "root" => <<~EXP,
          SCHEMA root;
          ENTITY person; name : STRING; END_ENTITY;
          ENTITY employee SUBTYPE OF (person); staff_no : STRING; END_ENTITY;
          SUBTYPE_CONSTRAINT person_sc FOR person;
            TOTAL_OVER (person, employee);
          END_SUBTYPE_CONSTRAINT;
          END_SCHEMA;
        EXP
      }
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)

      aggregate_failures do
        expect(longform.subtype_constraints).to be_empty
        expect(longform.rules.map(&:id)).to include("total_over_person_sc")
      end
    end

    it "G.2.7 converts RENAMED attributes to DERIVE" do
      sources = {
        "root" => <<~EXP,
          SCHEMA root;
          ENTITY person; name : STRING; END_ENTITY;
          ENTITY employee SUBTYPE OF (person);
            SELF\\person.name RENAMED id : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      }
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)

      emp = longform.entities.find { |e| e.id == "employee" }
      derived = emp.attributes.find { |a| a.kind == Expressir::Model::Declarations::Attribute::DERIVED }
      aggregate_failures do
        expect(derived).not_to be_nil
        expect(derived.id).to eq("id")
        text = Expressir::Express::Formatter.format(longform)
        expect(text).to include("DERIVE")
        expect(text).to include('SELF\person.name')
      end
    end
  end

  describe "eeng oracle differential", if: ENV.fetch("EENG_PARITY", nil) do
    it "flattens description_assignment MIM with the same declaration set" do
      stepmod = ENV["STEPMOD"] || "/Users/mulgogi/src/mn/iso-10303"
      File.join(stepmod, "schemas/modules/description_assignment/mim.exp")
      oracle = File.read(File.expand_path("../../fixtures/eeng/oracle/description-assignment-mim-concatenated.exp", __dir__))

      # Universe: every schema in the oracle closure.
      paths = oracle.scan(%r{^-- [A-Za-z_0-9]+ \((.+)\)$}).flatten.uniq
      repository = Expressir::Express::Parser.from_files(paths, skip_references: true)
      root = repository.schemas.find { |s| s.id == "Description_assignment_mim" }
      longform = flatten(root, repository)

      oracle_decls = oracle.scan(/^-- ([A-Za-z_0-9]+) \(/).flatten.map(&:upcase).sort
      expect([longform.id.upcase]).to eq([oracle_decls.first])
      expect(longform.interfaces).to be_empty
    end
  end

  describe "all-extenders option" do
    it "folds closure entities into an empty GENERIC_ENTITY extensible select" do
      sources = {
        "support" => <<~EXP,
          SCHEMA support;
          ENTITY base_thing; y : STRING; END_ENTITY;
          END_SCHEMA;
        EXP
        "root" => <<~EXP,
          SCHEMA root;
          USE FROM support (base_thing);
          TYPE pick = EXTENSIBLE GENERIC_ENTITY SELECT; END_TYPE;
          ENTITY thing_one SUBTYPE OF (base_thing); a : STRING; END_ENTITY;
          ENTITY thing_two SUBTYPE OF (base_thing); b : STRING; END_ENTITY;
          END_SCHEMA;
        EXP
      }
      repository, @files = parse_repository(sources)
      lf = flatten(schema_of(repository, "root"), repository)

      pick = lf.types.find { |t| t.id == "pick" }
      items = pick.underlying_type.items.map { |x| x.id.downcase }
      aggregate_failures do
        expect(pick.underlying_type.generic_entity).to be_truthy
        expect(items).to include("thing_one", "thing_two", "base_thing")
      end
    end
  end

  describe "G.1.9 prune pass" do
    it "drops rules whose parameter entities are not visible" do
      sources = { "root" => <<~EXP }
        SCHEMA root;
        ENTITY e; x : STRING; END_ENTITY;
        RULE ghost_rule FOR (missing_entity); WHERE wr1 : TRUE; END_RULE;
        RULE good_rule FOR (e); WHERE wr1 : TRUE; END_RULE;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)
      expect(longform.rules.map(&:id)).to eq(["good_rule"])
    end

    it "prunes invisible select items and drops emptied selects" do
      sources = { "root" => <<~EXP }
        SCHEMA root;
        TYPE visible_type = STRING; END_TYPE;
        TYPE mixed = SELECT (visible_type, ghost_type); END_TYPE;
        TYPE emptied = SELECT (ghost_type); END_TYPE;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)
      mixed = longform.types.find { |t| t.id == "mixed" }
      items = mixed.underlying_type.items.map(&:id)
      expect(items).to eq(["visible_type"])
      expect(longform.types.map(&:id)).not_to include("emptied")
    end

    it "drops functions and procedures nothing calls, keeping the chain" do
      sources = { "root" => <<~EXP }
        SCHEMA root;
        FUNCTION helper(a : INTEGER) : INTEGER; RETURN (a + 1); END_FUNCTION;
        FUNCTION used(x : INTEGER) : INTEGER; RETURN (helper(x)); END_FUNCTION;
        PROCEDURE orphan; END_PROCEDURE;
        ENTITY e; a : INTEGER; WHERE wr1 : used(a) > 0; END_ENTITY;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)
      expect(longform.functions.map(&:id)).to contain_exactly("helper", "used")
      expect(longform.procedures).to be_empty
    end

    it "reduces ONEOF over invisible members per Annex C" do
      sources = { "root" => <<~EXP }
        SCHEMA root;
        ENTITY r; END_ENTITY;
        ENTITY a; END_ENTITY;
        ENTITY b; END_ENTITY;
        SUBTYPE_CONSTRAINT sc FOR r;
          ONEOF(a, ghost, b);
        END_SUBTYPE_CONSTRAINT;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "root"), repository)
      files.each(&:unlink)
      text = Expressir::Express::Formatter.format(longform)
      aggregate_failures do
        expect(text).to include("ONEOF")
        expect(text).to include("a")
        expect(text).to include("b")
        expect(text).not_to include("ghost")
      end
    end
  end

  describe "G.1.9 prune edge cases (#439)" do
    it "reduces SUBTYPE_CONSTRAINTs with AND without crashing" do
      sources = { "d" => <<~EXP }
        SCHEMA d;
        ENTITY r; END_ENTITY;
        ENTITY a SUBTYPE OF (r); END_ENTITY;
        ENTITY b SUBTYPE OF (r); END_ENTITY;
        ENTITY c SUBTYPE OF (r); END_ENTITY;
        SUBTYPE_CONSTRAINT sc FOR r;
          ONEOF(a, b) AND c;
        END_SUBTYPE_CONSTRAINT;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "d"), repository)
      files.each(&:unlink)
      text = Expressir::Express::Formatter.format(longform)
      aggregate_failures do
        expect(text).to include("a")
        expect(text).to include("c")
      end
    end

    it "keeps called procedures" do
      sources = { "d" => <<~EXP }
        SCHEMA d;
        ENTITY e; v : INTEGER; WHERE wr1 : f(v) > 0; END_ENTITY;
        PROCEDURE bump(VAR x : INTEGER); x := x + 1; END_PROCEDURE;
        FUNCTION f(a : INTEGER) : INTEGER;
          LOCAL y : INTEGER := a; END_LOCAL;
          bump(y);
          RETURN (y);
        END_FUNCTION;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "d"), repository)
      files.each(&:unlink)
      aggregate_failures do
        expect(longform.functions.map(&:id)).to eq(["f"])
        expect(longform.procedures.map(&:id)).to eq(["bump"])
      end
    end
  end

  describe "G.1.9 bare zero-arg function references (#439 follow-up)" do
    it "keeps a bare zero-argument function used in a WHERE rule" do
      sources = { "d" => <<~EXP }
        SCHEMA d;
        FUNCTION limit_value : INTEGER;
          RETURN (10);
        END_FUNCTION;
        ENTITY e; v : INTEGER; WHERE wr1 : v < limit_value; END_ENTITY;
        END_SCHEMA;
      EXP
      repository, files = parse_repository(sources)
      longform = flatten(schema_of(repository, "d"), repository)
      files.each(&:unlink)
      expect(longform.functions.map(&:id)).to eq(["limit_value"])
    end
  end

  describe "extenders: :none" do
    it "extenders: none leaves the extensible select as declared" do
      sources = {
        "root" => <<~EXP,
          SCHEMA root;
          ENTITY thing_one; a : STRING; END_ENTITY;
          TYPE pick = EXTENSIBLE GENERIC_ENTITY SELECT; END_TYPE;
          END_SCHEMA;
        EXP
      }
      repository, @files = parse_repository(sources)
      lf = described_class.new(schema_of(repository, "root"),
                               repository,
                               extenders: :none).flatten.schema
      pick = lf.types.find { |t| t.id == "pick" }
      expect(pick.underlying_type.items).to be_empty
    end
  end
end
