# frozen_string_literal: true

require "spec_helper"

# eeng kernel/compute-inheritance.lisp + derive-attrs.lisp +
# inverse-attrs.lisp: inherited attributes and closures, materialized
# onto the entity (TODO.eengine/03).
RSpec.describe Expressir::Model::Declarations::Entity do
  let(:repo) do
    Expressir::Express::Parser.from_exp(<<~EXP, skip_references: true)
      SCHEMA base_types;
      CONSTANT dummy : INTEGER := 0; END_CONSTANT;
      ENTITY root;
        base_id : STRING;
        base_kind : INTEGER;
        DERIVE
          derived_in_base : INTEGER := 1;
        INVERSE
          back_refs : referencing FOR base_ref;
        END_ENTITY;
      ENTITY branch SUBTYPE OF (root);
        branch_specific : INTEGER;
        DERIVE
          derived_in_branch : INTEGER := 2;
        END_ENTITY;
      ENTITY leaf SUBTYPE OF (branch);
        base_id : STRING; -- redeclaration of root.base_id
        DERIVE
          derived_in_leaf : INTEGER := 3;
        INVERSE
          leaf_back : referencing FOR base_ref;
        END_ENTITY;
      ENTITY referencing; base_ref : root; END_ENTITY;
      END_SCHEMA;
      SCHEMA cross;
      USE FROM base_types (leaf);
      ENTITY imported SUBTYPE OF (leaf);
        cross_specific : INTEGER;
      END_ENTITY;
      END_SCHEMA;
    EXP
  end

  def schema_entities(schema_id)
    repo.schemas.find { |s| s.id == schema_id }.entities
  end

  def entity(schema_id, id)
    schema_entities(schema_id).find { |e| e.id == id }
  end

  describe "#supertype_closure" do
    it "closes the chain nearest-first" do
      leaf = entity("base_types", "leaf")
      expect(leaf.supertype_closure.map(&:id)).to eq(%w[branch root])
    end

    it "resolves cross-schema supertypes" do
      imported = entity("cross", "imported")
      expect(imported.supertype_closure.map(&:id)).to eq(%w[leaf branch root])
    end
  end

  describe "#inherited_explicit_attributes" do
    it "materializes the closure, redeclaration-aware" do
      leaf = entity("base_types", "leaf")
      inherited = leaf.inherited_explicit_attributes.map(&:id)
      expect(inherited).to eq(%w[branch_specific base_kind])
      all_ids = leaf.all_explicit_attributes.map(&:id)
      expect(all_ids).to eq(%w[base_id branch_specific base_kind])
    end

    it "accumulates the full closure for mid-level entities" do
      branch = entity("base_types", "branch")
      expect(branch.inherited_explicit_attributes.map(&:id)).to eq(%w[base_id base_kind])
    end
  end

  describe "derived and inverse closures" do
    it "accumulates derived attributes from the closure" do
      leaf = entity("base_types", "leaf")
      expect(leaf.inherited_derived_attributes.map(&:id))
        .to eq(%w[derived_in_branch derived_in_base])
    end

    it "accumulates inverse attributes from the closure" do
      leaf = entity("base_types", "leaf")
      expect(leaf.inherited_inverse_attributes.map(&:id))
        .to eq(%w[back_refs])
    end
  end
end
