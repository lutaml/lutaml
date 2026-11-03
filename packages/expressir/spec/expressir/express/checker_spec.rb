# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# eeng kernel/check.lisp note-id parity — subset covered by Checker.
# Fixtures use multi-line entity bodies to stay outside expressir#373's
# small single-line corruption window.
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

  describe "check-schema-interface-redundant" do
    it "flags a second identical USE FROM" do
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

  describe "check-schema-iface-resource-duplicate" do
    it "flags overlapping resources across two interfaces to the same schema" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          END_ENTITY;
          ENTITY f;
            y : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (e);
          USE FROM a (e, f);
          END_SCHEMA;
        EXP
      )
      expect(result.notes.map(&:id)).to include(:check_schema_iface_resource_duplicate)
    end
  end

  describe "check-unresolved-ref (missing interface schema)" do
    it "errors when the foreign schema is absent" do
      result = check(
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM missing (e);
          END_SCHEMA;
        EXP
      )
      note = result.errors.find { |n| n.id == :check_unresolved_ref }
      expect(note).not_to be_nil
      expect(note.message).to include("missing")
    end
  end

  describe "check-unresolved-ref (missing resource)" do
    it "errors when an interface item is not declared in the foreign schema" do
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
          USE FROM a (nope);
          END_SCHEMA;
        EXP
      )
      note = result.errors.find { |n| n.id == :check_unresolved_ref && n.message.include?("nope") }
      expect(note).not_to be_nil
    end
  end

  describe "check-where-name-pattern" do
    it "warns when a WHERE label is not WR<n>" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          WHERE
            bad_label: TRUE;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.warnings.map(&:id)).to include(:check_where_name_pattern)
    end

    it "accepts WR1-style labels" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          WHERE
            WR1: TRUE;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.notes.map(&:id)).not_to include(:check_where_name_pattern)
    end
  end

  describe "check-unique-name-pattern" do
    it "warns when a UNIQUE label is not UR<n>" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          UNIQUE
            badu : x;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.warnings.map(&:id)).to include(:check_unique_name_pattern)
    end
  end

  describe "check-subtype-ref" do
    it "errors when SUBTYPE OF names an unknown entity" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e SUBTYPE OF (ghost);
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_subtype_ref)
    end
  end

  describe "check-select-extended-type" do
    it "errors when BASED_ON names an unknown type" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY e;
            x : STRING;
          END_ENTITY;
          TYPE s = SELECT BASED_ON missing WITH (e);
          END_TYPE;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_select_extended_type)
    end
  end

  describe "check-subtype-cycle (#411)" do
    it "does not report a cycle for convergent (diamond) branches" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY root;
            x : STRING;
          END_ENTITY;
          ENTITY left SUBTYPE OF (root);
            a : STRING;
          END_ENTITY;
          ENTITY right SUBTYPE OF (root);
            b : STRING;
          END_ENTITY;
          ENTITY bottom SUBTYPE OF (left, right);
            c : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).not_to include(:check_subtype_cycle)
    end

    it "still reports true cycles" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY p SUBTYPE OF (q);
            x : STRING;
          END_ENTITY;
          ENTITY q SUBTYPE OF (p);
            y : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_subtype_cycle)
    end
  end

  describe "check-unresolved-ref built-in coverage (#412)" do
    it "does not flag blength, insert, or remove as unresolved" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY e;
            items : LIST [0:?] OF e;
          END_ENTITY;
          FUNCTION f(items : LIST [0:?] OF e) : INTEGER;
            LOCAL n : INTEGER := 0; END_LOCAL;
            IF SIZEOF(items) > 0 THEN
              n := BLENGTH(items);
            END_IF;
            INSERT(items, e(''));
            REMOVE(items);
            RETURN (n);
          END_FUNCTION;
          END_SCHEMA;
        EXP
      )
      unresolved = result.errors.select { |n| n.message =~ /blength|insert|remove/i }
      expect(unresolved).to be_empty
    end
  end

  describe "check-subtypeof-invalid" do
    it "flags a SUBTYPE OF naming a TYPE" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          TYPE thing = STRING; END_TYPE;
          ENTITY e SUBTYPE OF (thing);
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_subtypeof_invalid)
    end
  end

  describe "check-supertype-ref" do
    it "flags an unknown entity in the SUPERTYPE expression" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY base ABSTRACT SUPERTYPE OF (ONEOF(a, ghost));
          END_ENTITY;
          ENTITY a SUBTYPE OF (base);
            x : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_supertype_ref)
    end
  end

  describe "check-select-named-type" do
    it "accepts select items naming entities (#438: named_types include entities)" do
      result = check(
        "d" => <<~EXP,
          SCHEMA sel;
          ENTITY person; name : STRING; END_ENTITY;
          ENTITY organization; name : STRING; END_ENTITY;
          TYPE party = SELECT (person, organization);
          END_TYPE;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).not_to include(:check_select_named_type)
    end

    it "flags select items naming neither a type nor an entity" do
      result = check(
        "d" => <<~EXP,
          SCHEMA sel;
          TYPE label = STRING; END_TYPE;
          TYPE bad = SELECT (label, no_such_thing);
          END_TYPE;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_select_named_type)
    end
  end

  describe "check-agg-type" do
    it "flags inverted aggregate bounds" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY e;
            items : LIST [5:2] OF STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_agg_type)
    end

    it "accepts ordered aggregate bounds" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY e;
            items : LIST [2:5] OF STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).not_to include(:check_agg_type)
    end
  end

  describe "check-attrib-name-fun" do
    it "warns when an attribute shadows a function name" do
      result = check(
        "d" => <<~EXP,
          SCHEMA d;
          ENTITY e;
            weight : INTEGER;
          END_ENTITY;
          FUNCTION weight(x : INTEGER) : INTEGER;
            RETURN (x);
          END_FUNCTION;
          END_SCHEMA;
        EXP
      )
      expect(result.warnings.map(&:id)).to include(:check_attrib_name_fun)
    end
  end

  describe "check-string-no-entity" do
    it "flags 'SCHEMA.ITEM' strings whose item is not declared" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          USE FROM b (thing);
          ENTITY e;
            x : STRING;
          WHERE
            wr1 : TYPEOF(x) <> 'B.GHOST';
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          ENTITY thing; y : STRING; END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.warnings.map(&:id)).to include(:check_string_no_entity)
    end
  end

  describe "check-inverse-entity" do
    it "flags an INVERSE target that is not an entity" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          TYPE label = STRING;
          END_TYPE;
          ENTITY holder;
            id : STRING;
          INVERSE
            inv : label FOR id;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_inverse_entity)
    end
  end

  describe "check-inverse-attrib-ref" do
    it "flags an INVERSE naming a missing attribute" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY holder;
            id : STRING;
          INVERSE
            inv : holder FOR ghost;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_inverse_attrib_ref)
    end
  end

  describe "check-inverse-derive" do
    it "flags an INVERSE pairing with a DERIVE attribute" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY holder;
            id : STRING;
          DERIVE
            dv : STRING := 'x';
          INVERSE
            inv : holder FOR dv;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_inverse_derive)
    end
  end

  describe "check-inverse-inverse" do
    it "flags an INVERSE pairing with another INVERSE" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY pair;
            dr : pair;
          INVERSE
            back : pair FOR dr;
            bad : pair FOR back;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id)).to include(:check_inverse_inverse)
    end
  end

  describe "qualified-attrib-group-not-found" do
    it "flags a group qualifier that resolves to no entity" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY holder;
            id : STRING;
          WHERE
            WR1: EXISTS(SELF\\ghost.g);
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id))
        .to include(:qualified_attrib_group_not_found)
    end
  end

  describe "qualified-attrib-group-not-ancestor" do
    it "flags a redeclared SELF group outside the supertype chain" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY base;
            n : STRING;
          END_ENTITY;
          ENTITY other;
            k : STRING;
          END_ENTITY;
          ENTITY adopter SUBTYPE OF (base);
            SELF\\other.k RENAMED stolen : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id))
        .to include(:qualified_attrib_group_not_ancestor)
    end
  end

  describe "qualified-attrib-attr-not-found" do
    it "flags a group qualifier naming a missing attribute" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY base;
            n : STRING;
          END_ENTITY;
          ENTITY sub SUBTYPE OF (base);
          WHERE
            WR1: EXISTS(SELF\\base.ghost);
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result.errors.map(&:id))
        .to include(:qualified_attrib_attr_not_found)
    end
  end

  describe "SELF group and INVERSE clean forms" do
    it "accepts valid qualifiers and inverse pairings" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          ENTITY base;
            n : STRING;
          END_ENTITY;
          ENTITY sub SUBTYPE OF (base);
            dr : sub;
          DERIVE
            dv : STRING := SELF\\base.n;
          INVERSE
            back : sub FOR dr;
          WHERE
            WR1: EXISTS(SELF\\base.n);
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      tranche3 = %i[check_inverse_entity check_inverse_attrib_ref
                    check_inverse_inverse check_inverse_derive
                    qualified_attrib_group_not_found
                    qualified_attrib_group_not_ancestor
                    qualified_attrib_attr_not_found]
      expect(result.notes.map(&:id) & tranche3).to be_empty
    end
  end

  describe "clean schema" do
    it "reports no errors for a self-contained schema" do
      result = check(
        "a" => <<~EXP,
          SCHEMA a;
          TYPE t = STRING; END_TYPE;
          ENTITY e;
            x : t;
          UNIQUE
            UR1 : x;
          WHERE
            WR1: TRUE;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      expect(result).to be_valid
    end
  end
end
