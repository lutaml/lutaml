# frozen_string_literal: true

require "spec_helper"

# eeng check-p11 context checks (kernel/check.lisp:160-201, 299-336,
# 337-395): constant/local/parameter/return types resolve via
# find-type/entity - types and entities only.
RSpec.describe Expressir::Express::Checker do
  let(:repo) do
    Expressir::Express::Parser.from_exp(<<~EXP, skip_references: true)
      SCHEMA res;
      CONSTANT good_const : color := ?; END_CONSTANT;
      TYPE color = ENUMERATION OF (red, green); END_TYPE;
      ENTITY thing; v : color; END_ENTITY;
      FUNCTION good_fn(p : color) : color;
        LOCAL good_local : color; END_LOCAL;
      RETURN(p);
      END_FUNCTION;
      PROCEDURE good_proc(p : color);
        LOCAL good_plocal : color; END_LOCAL;
      END_PROCEDURE;
      RULE good_rule FOR (thing); WHERE wr1 : TRUE; END_RULE;
      END_SCHEMA;
      SCHEMA broken;
      CONSTANT bad_const : nosuchtype := ?; END_CONSTANT;
      FUNCTION bad_fn(p : nosuchparam) : nosuchreturn;
        LOCAL bad_local : nosuchlocal; END_LOCAL;
      RETURN(p);
      END_FUNCTION;
      PROCEDURE bad_proc(p : nosuchprocparam);
        LOCAL bad_plocal : nosuchproclocal; END_LOCAL;
      END_PROCEDURE;
      RULE bad_rule FOR (nosuchentity); WHERE wr1 : TRUE; END_RULE;
      END_SCHEMA;
    EXP
  end

  let(:notes) { described_class.new(repo).check.notes }

  it "keeps the clean schema free of type-resolution notes" do
    schema_name = ->(n) { n.schema.is_a?(String) ? n.schema : n.schema&.id }
    res_notes = notes.select { |n| schema_name.call(n) == "res" }
    expect(res_notes.select do |n|
      n.id.to_s.start_with?("check_constant_type", "check_parameter_type",
                            "check_function_return_type", "check_local_type")
    end)
      .to be_empty
  end

  it "notes the broken schema's constant type" do
    expect(note_for(:check_constant_type, "bad_const")).not_to be_nil
  end

  it "notes the broken schema's parameter types" do
    expect(note_for(:check_parameter_type, "p", "nosuchparam")).not_to be_nil
    expect(note_for(:check_parameter_type, "p", "nosuchprocparam")).not_to be_nil
  end

  it "notes the broken schema's function return type" do
    expect(note_for(:check_function_return_type, "bad_fn")).not_to be_nil
  end

  it "notes the broken schema's local types" do
    expect(note_for(:check_local_type, "bad_local")).not_to be_nil
    expect(note_for(:check_local_type, "bad_plocal")).not_to be_nil
  end

  it "notes the broken rule's FOR entity" do
    expect(note_for(:check_parameter_type, "bad_rule", "nosuchentity")).not_to be_nil
  end

  it "emits every type-resolution note as an error" do
    typed = notes.select do |n|
      n.id.to_s.start_with?("check_constant_type", "check_parameter_type",
                            "check_function_return_type", "check_local_type")
    end
    expect(typed.map(&:severity).uniq).to eq([:error])
  end

  def note_for(id, name, type_text = nil)
    notes.find do |n|
      n.id == id && n.message.include?("'#{name}'") &&
        (type_text.nil? || n.message.include?("'#{type_text}'"))
    end
  end
end
