# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# Review findings #399–#405 against the Checker. Fixtures use multi-line
# entity bodies to stay outside expressir#373's small single-line window.
RSpec.describe Expressir::Express::Checker do
  def parse_repository(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path))
    [repository, files]
  end

  def files
    @files ||= []
  end

  after do
    files.each(&:unlink)
  end

  def check(sources)
    repository, parsed = parse_repository(sources)
    files.concat(parsed)
    described_class.new(repository).check
  end

  describe "#405 case-colliding schema ids" do
    it "resolves interface resources against the exact-case schema" do
      result = check(
        "x" => <<~EXP,
          SCHEMA Foo;
          ENTITY only_in_upper;
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "y" => <<~EXP,
          SCHEMA foo;
          ENTITY only_in_lower;
            y : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "z" => <<~EXP,
          SCHEMA user_s;
          USE FROM Foo (only_in_upper);
          END_SCHEMA;
        EXP
      )
      unresolved = result.errors.select do |n|
        n.id == :check_unresolved_ref && n.message.include?("only_in_upper")
      end
      expect(unresolved).to be_empty
    end
  end

  describe "#404 inheritance cycles" do
    it "flags mutual and self subtyping" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY p SUBTYPE OF (q);
            x : STRING;
          END_ENTITY;
          ENTITY q SUBTYPE OF (p);
            y : STRING;
          END_ENTITY;
          ENTITY selfie SUBTYPE OF (selfie);
            z : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      cycles = result.errors.select { |n| n.id == :check_subtype_cycle }
      aggregate_failures do
        expect(cycles.map(&:schema)).to all(eq("a"))
        expect(cycles.map(&:message)).to contain_exactly(a_string_matching(/ENTITY p: .* 'p'/), a_string_matching(/ENTITY q: .* 'q'/), a_string_matching(/ENTITY selfie: .* 'selfie'/))
      end
    end

    it "does not flag a linear chain" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY base;
            x : STRING;
          END_ENTITY;
          ENTITY mid SUBTYPE OF (base);
            y : STRING;
          END_ENTITY;
          ENTITY top SUBTYPE OF (mid);
            z : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).not_to include(:check_subtype_cycle)
    end
  end

  describe "#403 duplicate declarations" do
    it "flags duplicate entity and type ids in one schema" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          END_ENTITY;
          ENTITY e;
            y : STRING;
          END_ENTITY;
          TYPE t = STRING; END_TYPE;
          TYPE t = INTEGER; END_TYPE;
          END_SCHEMA;
        EXP
      )
      dups = result.errors.select { |n| n.id == :check_duplicate_declaration }
      expect(dups.size).to eq(2)
    end
  end

  describe "#402 interface kinds are not conflated" do
    it "does not flag a USE FROM plus REFERENCE FROM of the same item" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (e);
          REFERENCE FROM a (e);
          END_SCHEMA;
        EXP
      )
      expect(result.notes.map(&:id)).not_to include(:check_schema_interface_redundant)
    end

    it "still flags two USE FROMs of the same item" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (e);
          USE FROM a (e);
          END_SCHEMA;
        EXP
      )
      expect(result.notes.map(&:id)).to include(:check_schema_interface_redundant)
    end
  end

  describe "#401 dead function/procedure where checks" do
    it "runs check_schema without touching function where_rules" do
      sources = {
        "a" => <<~EXP,
          SCHEMA a;
          FUNCTION f : INTEGER;
            LOCAL v : INTEGER; END_LOCAL;
            RETURN (v);
          END_FUNCTION;
          END_SCHEMA;
        EXP
      }
      repository, parsed = parse_repository(sources)
      files.concat(parsed)
      expect { described_class.new(repository).check }.not_to raise_error
    end
  end

  describe "#400 TYPE-level WHERE labels" do
    it "warns on a non-WR label in a TYPE" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          TYPE t = INTEGER;
          WHERE
            bad_label : SELF > 0;
          END_TYPE;
          ENTITY e;
            q : t;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.warnings.map(&:id)).to include(:check_where_name_pattern)
    end
  end

  describe "#399 interface AS-renames resolve for SUBTYPE OF and BASED_ON" do
    it "accepts SUBTYPE OF through an alias" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY base_thing;
            x : STRING;
          END_ENTITY;
          TYPE base_t = STRING; END_TYPE;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (base_thing AS bt, base_t AS bt2);
          ENTITY derived SUBTYPE OF (bt);
            y : bt2;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      relevant = result.errors.reject do |n|
        n.id == :check_unresolved_ref && n.message.include?("only")
      end
      subtype_notes = relevant.select do |n|
        n.id == :check_subtype_ref || n.message.include?("bt")
      end
      expect(subtype_notes).to be_empty
    end
  end

  describe "check_unresolved_ref vs locally bound identifiers (#396)" do
    it "accepts the Libes mini2 longform that eep -t accepts" do
      src = <<~EXP
        SCHEMA mini2_lf;
        ENTITY shape
          SUPERTYPE OF (circle);
          nm : STRING;
        END_ENTITY;
        ENTITY circle
          SUBTYPE OF (shape);
          r : REAL;
        WHERE
          WR1 : r > 0.0;
        END_ENTITY;
        ENTITY small_circle
          SUBTYPE OF (circle);
        WHERE
          WR1 : r < 1.0;
        END_ENTITY;
        FUNCTION pick(cs : LIST [0:?] OF small_circle) : INTEGER;
          LOCAL
            n : INTEGER := 0;
          END_LOCAL;
          REPEAT i := 1 TO SIZEOF(cs);
            n := n + cs[i].r;
          END_REPEAT;
          RETURN (SIZEOF(QUERY(q <* cs | q\\circle.r > 0.5)) + n);
        END_FUNCTION;
        END_SCHEMA;
      EXP
      file = Tempfile.new(["mini2_lf", ".exp"])
      file.write(src)
      file.close
      begin
        repo = Expressir::Express::Parser.from_files([file.path])
        result = described_class.new(repo).check
        aggregate_failures do
          expect(result.notes).to be_empty
          expect(result).to be_valid
        end
      ensure
        file.unlink
      end
    end
  end
end
