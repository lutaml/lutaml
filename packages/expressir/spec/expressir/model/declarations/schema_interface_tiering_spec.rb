# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Model::Declarations::Schema do
  # eeng resolve-interface: use-from resolves via find-type/entity;
  # reference-from via constant/entity/function/procedure/type.
  # ISO 10303-11: implicit interfacing happens through USE only.
  let(:repo) do
    Expressir::Express::Parser.from_exp(<<~EXP, skip_references: true)
      SCHEMA foreign;
      CONSTANT the_const : INTEGER := 1; END_CONSTANT;
      TYPE kind = ENUMERATION OF (a, b); END_TYPE;
      ENTITY thing; END_ENTITY;
      FUNCTION helper : INTEGER; RETURN(1); END_FUNCTION;
      PROCEDURE helper_procedure; END_PROCEDURE;
      RULE the_rule FOR (thing); WHERE wr1 : TRUE; END_RULE;
      END_SCHEMA;
      SCHEMA unlisted_use;
      USE FROM foreign;
      ENTITY consumer; v : thing; END_ENTITY;
      END_SCHEMA;
      SCHEMA listed_use;
      USE FROM foreign (kind, thing, helper);
      ENTITY consumer; v : thing; END_ENTITY;
      END_SCHEMA;
      SCHEMA referrer;
      REFERENCE FROM foreign (the_const, helper, thing, the_rule);
      ENTITY consumer; v : thing; n : INTEGER; END_ENTITY;
      END_SCHEMA;
      SCHEMA unlisted_ref;
      REFERENCE FROM foreign;
      ENTITY consumer; v : thing; END_ENTITY;
      END_SCHEMA;
    EXP
  end

  let(:schemas) { repo.schemas.group_by(&:id) }

  def exposed(schema_id)
    schema = schemas[schema_id].first
    schema.children
      .grep(Expressir::Model::Declarations::InterfacedItem)
      .map(&:id).sort
  end

  it "exposes only entities and types through an unlisted USE" do
    expect(exposed("unlisted_use")).to eq(%w[kind thing])
  end

  it "resolves listed USE items of interfacable kinds and drops the rest" do
    expect(exposed("listed_use")).to eq(%w[kind thing])
  end

  it "resolves listed REFERENCE items of all five interfacable kinds" do
    expect(exposed("referrer")).to eq(%w[helper the_const thing])
  end

  it "gives an unlisted REFERENCE no implicit interfacing" do
    expect(exposed("unlisted_ref")).to eq([])
  end

  it "flags kind-restricted USE items as errors in the checker" do
    result = Expressir::Express::Checker.new(repo).check
    note = result.errors.find do |n|
      n.id == :check_interface_kind_restriction && n.message.include?("helper")
    end
    expect(note).not_to be_nil
    expect(note.severity).to eq(:error)
  end
end
