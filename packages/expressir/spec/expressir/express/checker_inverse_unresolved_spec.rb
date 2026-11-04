# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::Express::Checker do
  it "reports an unresolvable inverse pair without crashing on a missing supertype" do
    source = <<~EXPRESS
      SCHEMA unresolved_supertype;
      ENTITY child SUBTYPE OF (missing_super);
        x : INTEGER;
      END_ENTITY;
      ENTITY holder;
        INVERSE children : SET [0:?] OF child FOR child.y;
      END_ENTITY;
      END_SCHEMA;
    EXPRESS
    repository = Expressir::Express::Parser.from_exp(source)
    notes = described_class.new(
      Expressir::Model::Repository.new(files: [repository]),
    ).check.notes

    expect(notes.map(&:id)).to include(:check_inverse_attrib_ref)
  end
end
