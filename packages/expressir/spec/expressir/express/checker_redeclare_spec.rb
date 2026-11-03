# frozen_string_literal: true

require "spec_helper"
require "expressir"

# TODO.eengine/02 remainder: subtype-constraint supertype refs
# (eeng check.lisp:426) and SELF\ redeclaration resolution
# (ISO 10303-11:2004, 9.2.2.3).
RSpec.describe Expressir::Express::Checker do
  def check(exp)
    repository = Expressir::Express::Parser.from_exp(exp)
    described_class.new(repository).tap(&:check)
  end

  def notes_for(repository, id)
    repository.notes.select { |note| note.id == id }
  end

  describe "subtype constraint supertype references" do
    let(:clean) do
      check(<<~EXPRESS)
        SCHEMA sc;
          ENTITY base; END_ENTITY;
          ENTITY a SUBTYPE OF (base); END_ENTITY;
          ENTITY b SUBTYPE OF (base); END_ENTITY;
          SUBTYPE_CONSTRAINT base_sc FOR base;
            ONEOF (a, b);
          END_SUBTYPE_CONSTRAINT;
        END_SCHEMA;
      EXPRESS
    end

    it "accepts a constraint whose expression resolves" do
      expect(notes_for(clean, :check_supertype_ref)).to be_empty
    end

    it "flags an expression reference that is not an entity" do
      repository = check(<<~EXPRESS)
        SCHEMA sc;
          ENTITY base; END_ENTITY;
          ENTITY a SUBTYPE OF (base); END_ENTITY;
          TYPE t = INTEGER; END_TYPE;
          SUBTYPE_CONSTRAINT base_sc FOR base;
            ONEOF (a, t);
          END_SUBTYPE_CONSTRAINT;
        END_SCHEMA;
      EXPRESS
      notes = notes_for(repository, :check_supertype_ref)
      expect(notes).not_to be_empty
      expect(notes.first.message).to include("SUBTYPE_CONSTRAINT base_sc")
      expect(notes.first.message).to include("'t'")
    end
  end

  describe "SELF attribute redeclaration" do
    let(:clean) do
      check(<<~EXPRESS)
        SCHEMA sc;
          ENTITY base;
            x : INTEGER;
          END_ENTITY;
          ENTITY child SUBTYPE OF (base);
            SELF\\base.x : REAL;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
    end

    it "accepts a redeclaration of a real supertype attribute" do
      expect(notes_for(clean, :check_attribute_redeclaration)).to be_empty
    end

    it "flags a redeclaration naming a non-supertype" do
      repository = check(<<~EXPRESS)
        SCHEMA sc;
          ENTITY base; END_ENTITY;
          ENTITY other; END_ENTITY;
          ENTITY child SUBTYPE OF (base);
            SELF\\other.x : INTEGER;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
      notes = notes_for(repository, :check_attribute_redeclaration)
      expect(notes).not_to be_empty
      expect(notes.first.message).to include("'other', which is not a supertype")
    end

    it "flags a redeclaration of a missing supertype attribute" do
      repository = check(<<~EXPRESS)
        SCHEMA sc;
          ENTITY base; END_ENTITY;
          ENTITY child SUBTYPE OF (base);
            SELF\\base.x : INTEGER;
          END_ENTITY;
        END_SCHEMA;
      EXPRESS
      notes = notes_for(repository, :check_attribute_redeclaration)
      expect(notes).not_to be_empty
      expect(notes.first.message).to include("has no attribute 'x'")
    end
  end
end
