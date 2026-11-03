# frozen_string_literal: true

require "spec_helper"
require "parsanol"

RSpec.describe Expressir::Express::Grammar::Parser do
  describe ".artifact_available?" do
    it "is true in this repo (the compiled edition-2 artifact is checked in)" do
      expect(described_class.artifact_available?).to be(true)
    end
  end

  describe ".parse_artifact" do
    it "parses through the edition-2 artifact and yields named trees" do
      source = "schema s;\nend_schema;\n"

      tree = described_class.parse_artifact(source)

      expect(tree.keys).to eq([:syntax])
      schema_decls = tree[:syntax][:schemaDecl]
      expect(schema_decls.map { |d| d[:schemaDecl][:schemaId][:simpleId][:str] })
        .to eq(["s"])
    end
  end

  describe ".parse_ruby" do
    it "builds the same model as the DSL lane" do
      source = <<~EXP
        schema type_person;
          ENTITY person;
            name : STRING;
          END_ENTITY;
        END_SCHEMA;
      EXP

      artifact_tree = described_class.parse_ruby(source)
      dsl_tree = described_class.cached_parser.parse(source)

      artifact_model = Expressir::Express::Builder.build_with_remarks(
        artifact_tree, source: source, include_source: false
      )
      dsl_model = Expressir::Express::Builder.build_with_remarks(
        dsl_tree, source: source, include_source: false
      )

      expect(artifact_model.to_hash).to eq(dsl_model.to_hash)
    end
  end
end
