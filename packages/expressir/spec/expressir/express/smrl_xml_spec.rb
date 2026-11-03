# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Express::SmrlXml do
  def parse(sources)
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repository = Expressir::Express::Parser.from_files(files.map(&:path))
    [repository, files]
  end

  let(:sources) do
    {
      "support" => <<~EXP,
        SCHEMA support_schema;
        TYPE label = STRING; END_TYPE;
        END_SCHEMA;
      EXP
      "root" => <<~EXP,
        SCHEMA root_schema '{iso 10303-1}';
        USE FROM support_schema;
        REFERENCE FROM support_schema (label);
        TYPE zeta = STRING; END_TYPE;
        TYPE alpha = STRING; END_TYPE;
        ENTITY widget; x : label; END_ENTITY;
        ENTITY base_thing ABSTRACT SUPERTYPE; y : STRING; END_ENTITY;
        SUBTYPE_CONSTRAINT sc FOR widget; ONEOF(base_thing); END_SUBTYPE_CONSTRAINT;
        FUNCTION zfun(a : INTEGER) : INTEGER; RETURN (a); END_FUNCTION;
        FUNCTION afun(a : INTEGER) : INTEGER; RETURN (a); END_FUNCTION;
        RULE r1 FOR (widget); WHERE wr1 : TRUE; END_RULE;
        PROCEDURE p1; END_PROCEDURE;
        END_SCHEMA;
      EXP
    }
  end

  let(:repository) { parse(sources).first }
  let(:root) { repository.schemas.find { |s| s.id == "root_schema" } }

  it "emits the eeng wo-smrl-xml schema block" do
    xml = described_class.format_schema(root)
    aggregate_failures do
      expect(xml).to start_with("<schema>root_schema")
      expect(xml).to include("<schema_version>{iso 10303-1}</schema_version>")
      expect(xml).to include("<!--TYPE")
      expect(xml).to include("<!--ENTITY")
    end
  end

  it "lists interfaces with the item-list marker" do
    xml = described_class.format_schema(root)
    aggregate_failures do
      expect(xml).to include("<use-from>support_schema<")
      expect(xml).to include("<use-from>support_schema(...)<")
    end
  end

  it "orders declarations eeng-style and qualifies with the schema" do
    xml = described_class.format_schema(root)
    type_a = xml.index("<type>root_schema.alpha</type>")
    type_z = xml.index("<type>root_schema.zeta</type>")
    entity = xml.index("<entity>root_schema.widget</entity>")
    subtype = xml.index("<subtype-constraint>root_schema.sc</subtype-constraint>")
    fun_a = xml.index("<function>root_schema.afun</function>")
    rule = xml.index("<rule>root_schema.r1</rule>")
    proc = xml.index("<procedure>root_schema.p1</procedure>")
    aggregate_failures do
      expect(type_a).to be < type_z
      expect(type_z).to be < entity
      expect(entity).to be < subtype
      expect(subtype).to be < fun_a
      expect(fun_a).to be < rule
      expect(rule).to be < proc
    end
  end

  it "upcases entity names in ARM mode, downcases otherwise" do
    resource = described_class.format_schema(root)
    arm = described_class.format_schema(root, mode: :arm)
    expect(resource).to include("<entity>root_schema.widget</entity>")
    expect(arm).to include("<entity>root_schema.WIDGET</entity>")
  end

  it "formats every schema of a repository under an smrl root" do
    xml = described_class.format(repository)
    aggregate_failures do
      expect(xml).to include("<smrl>")
      expect(xml).to include("<schema>root_schema")
      expect(xml).to include("<schema>support_schema")
    end
  end

  # Schema-level CONSTANT blocks are a known parser gap (pending
  # roundtrip specs); cover the writer on a model-built schema.
  it "lists constants sorted" do
    schema = Expressir::Model::Declarations::Schema.new(
      id: "S",
      constants: [
        Expressir::Model::Declarations::Constant.new(
          id: "zeta", expression: Expressir::Model::Literals::Integer.new(value: "1"),
        ),
        Expressir::Model::Declarations::Constant.new(
          id: "alpha", expression: Expressir::Model::Literals::Integer.new(value: "2"),
        ),
      ],
    )
    xml = described_class.format_schema(schema)
    expect(xml.index("<constant>alpha</constant>")).to be < xml.index("<constant>zeta</constant>")
  end
end
