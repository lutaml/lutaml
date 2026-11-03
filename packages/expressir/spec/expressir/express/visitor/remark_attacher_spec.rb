# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::RemarkAttacher do
  describe "integration tests with real parsing" do
    let(:exp_file) do
      Expressir.root_path.join("spec", "fixtures", "validate_ascii",
                               "non_ascii_in_remarks_only.exp")
    end
    let(:repo) { Expressir::Express::Parser.from_file(exp_file) }
    let(:schema) { repo.schemas.first }
    let(:entity) { schema.entities.first }

    it "preserves tail remarks on entity attributes" do
      expect(entity.id).to eq("person")

      name_attr = entity.attributes.find { |a| a.id == "name" }
      expect(name_attr).not_to be_nil

      name_remark_texts = name_attr.untagged_remarks.map do |r|
        r.is_a?(Expressir::Model::RemarkInfo) ? r.text : r
      end
      expect(name_remark_texts).to include("Name in Japanese: 名前")

      entity_remarks = entity.untagged_remarks || []
      entity_remark_texts = entity_remarks.map do |r|
        r.is_a?(Expressir::Model::RemarkInfo) ? r.text : r
      end
      expect(entity_remark_texts).not_to include("Name in Japanese: 名前")
    end
  end

  describe "attach" do
    it "attaches remarks inside schema body to Schema" do
      source = <<~EXP
        SCHEMA test_schema;
        -- Schema level remark
        ENTITY test_entity;
        END_ENTITY;
        END_SCHEMA;
      EXP

      exp_file = Expressir::Express::Parser.from_exp(source)
      schema = exp_file.schemas.first

      expect(exp_file).to be_a(Expressir::Model::ExpFile)
      expect(schema.untagged_remarks).not_to be_empty
    end

    it "transfers file-level preamble remarks (before SCHEMA) to schema header" do
      source = <<~EXP
        (* File-level preamble *)
        SCHEMA test_schema;
        ENTITY test_entity;
        END_ENTITY;
        END_SCHEMA;
      EXP

      exp_file = Expressir::Express::Parser.from_exp(source)

      expect(exp_file).to be_a(Expressir::Model::ExpFile)
      expect(exp_file.untagged_remarks).to be_empty
      expect(exp_file.schemas.first.header).to eq("File-level preamble")
    end

    it "does not attach spurious tail remarks from inside documentation blocks" do
      # Regression guard for issue #308: an inline `--` inside an embedded
      # remark must not be split off as a tail remark.
      source = <<~EXP
        SCHEMA mini_schema;
        (*
        This schema provides representations for items a) -- d). that are mandatory in any application.

        [NOTE]
        --
        Scenarios of the expected use are described in the introduction.
        --
        *)
        END_SCHEMA;
      EXP

      exp_file = Expressir::Express::Parser.from_exp(source)
      schema = exp_file.schemas.first

      attached_texts = [exp_file, schema].flat_map do |node|
        (node.untagged_remarks || []).map(&:text)
      end + (schema.remarks || [])

      # No spurious tail remark was split off after the inline `--`.
      expect(attached_texts).not_to include(
        a_string_starting_with("d). that are mandatory"),
      )
      expect(attached_texts).not_to include("")
    end
  end

  describe "scanner integration" do
    # These specs cover the scanner↔attacher contract via the public
    # RemarkScanner interface, replacing the previous private-method probes
    # (send(:extract_all_remarks), instance_variable_get(:@line_cache)) which
    # violated encapsulation.

    it "extracts tail, embedded, and tagged remarks in source order" do
      source = <<~EXP
        SCHEMA test;
        -- plain tail remark
        --"WR1" tagged tail remark
        -- IP1: informal proposition tail
        (* embedded remark *)
        ENTITY foo;
        END_ENTITY;
        END_SCHEMA;
      EXP

      remarks = Expressir::Express::RemarkScanner.new(source).scan

      expect(remarks.map(&:format)).to eq(%w[tail tail tail embedded])
      expect(remarks[0].text).to eq("plain tail remark")
      expect(remarks[1].tag).to eq("WR1")
      expect(remarks[2].tag).to eq("IP1")
      expect(remarks[2].text).to eq("informal proposition tail")
      expect(remarks[3].text).to eq("embedded remark")
    end
  end

  describe "issue #130: SELF\\<supertype>.<attr> remark targets" do
    # Annotated EXPRESS remark tags reference redeclared attributes via
    # `SELF\<supertype>.<attr>` (ISO 10303-11 §9.2.3). The redeclared
    # attribute is indexed under its base name; the SELF qualifier must not
    # confuse path lookup.
    let(:source) do
      <<~EXP
        SCHEMA mathematical_functions_schema;

        ENTITY unary_generic_expression;
          operand : GENERIC_ENTITY;
        END_ENTITY;

        ENTITY dependent_variable_definition
          SUBTYPE OF (unary_generic_expression);
          name        : label;
          SELF\\unary_generic_expression.operand : GENERIC_ENTITY;
        END_ENTITY;

        (*"mathematical_functions_schema.dependent_variable_definition.SELF\\unary_generic_expression.operand"
        The expression defining the dependent variable.
        *)

        (*"mathematical_functions_schema.dependent_variable_definition.name"
        The label identifying the dependent variable.
        *)

        END_SCHEMA;
      EXP
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:schema) { repo.schemas.first }
    let(:entity) { schema.entities.find { |e| e.id == "dependent_variable_definition" } }

    it "attaches the remark to the redeclared (SELF\\...) attribute" do
      redeclared = entity.attributes.find { |a| a.id == "operand" }

      expect(redeclared).not_to be_nil
      expect(redeclared.remarks).to eq(["The expression defining the dependent variable."])
    end

    it "still attaches the remark to the plain attribute" do
      plain = entity.attributes.find { |a| a.id == "name" }

      expect(plain).not_to be_nil
      expect(plain.remarks).to eq(["The label identifying the dependent variable."])
    end
  end

  describe "issue #267: two redeclared attributes with same base name" do
    # When an entity redeclares the same attribute name from multiple
    # supertypes, each `SELF\<supertype>.<attr>` remark tag must attach to
    # the specific redeclared attribute (matched by supertype qualifier),
    # not collapse onto a single one.
    let(:source) do
      <<~EXP
        SCHEMA parameterization_schema;

        ENTITY maths_variable;
          name : label;
        END_ENTITY;

        ENTITY representation_item;
          name : label;
        END_ENTITY;

        ENTITY variational_parameter
          SUBTYPE OF (maths_variable, representation_item);
          SELF\\maths_variable.name : label;
          SELF\\representation_item.name : label;
        END_ENTITY;

        (*"parameterization_schema.variational_parameter.SELF\\maths_variable.name"
        The maths_variable name.
        *)

        (*"parameterization_schema.variational_parameter.SELF\\representation_item.name"
        The representation_item name.
        *)

        END_SCHEMA;
      EXP
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:schema) { repo.schemas.first }
    let(:entity) { schema.entities.find { |e| e.id == "variational_parameter" } }

    it "attaches each remark to the matching redeclared attribute" do
      maths_attr, repr_attr = entity.attributes

      expect(maths_attr.supertype_attribute.ref.entity.id).to eq("maths_variable")
      expect(repr_attr.supertype_attribute.ref.entity.id).to eq("representation_item")

      expect(maths_attr.remarks).to eq(["The maths_variable name."])
      expect(repr_attr.remarks).to eq(["The representation_item name."])
    end
  end

  describe "wr:IP prefix convention for informal propositions" do
    # EXPRESS annotated schemas use `(*"schema.entity.wr:IP1" ...*)` to
    # attach documentation to informal propositions. The `wr:` prefix
    # indicates the WHERE clause; the suffix `IP1` is the informal
    # proposition id.  The attacher must recognise this convention and
    # create InformalPropositionRule objects, not RemarkItems.
    let(:source) do
      <<~EXP
        SCHEMA test_schema;

        ENTITY test_entity
          SUBTYPE OF (base_entity);
        WHERE
          WR1 : SELF\\base_entity.attr > 0;
          WR2 : SIZEOF(QUERY(it <* SELF.items| TRUE)) = 0;
        END_ENTITY;

        (*"test_schema.test_entity.wr:WR1"
        The attribute shall be positive.
        *)

        (*"test_schema.test_entity.wr:WR2"
        All items shall satisfy the condition.
        *)

        (*"test_schema.test_entity.wr:IP1"
        This is the first informal proposition.
        *)

        (*"test_schema.test_entity.wr:IP2"
        This is the second informal proposition.
        *)

        (*"test_schema.test_entity.__note"
        This is a note on the entity.
        *)

        END_SCHEMA;
      EXP
    end
    let(:repo) { Expressir::Express::Parser.from_exp(source) }
    let(:schema) { repo.schemas.first }
    let(:entity) { schema.entities.find { |e| e.id == "test_entity" } }

    it "creates InformalPropositionRule objects from wr:IP tags" do
      expect(entity.informal_propositions).not_to be_nil
      expect(entity.informal_propositions.map(&:id)).to eq(%w[IP1 IP2])
    end

    it "attaches remark text to the IP's child RemarkItem" do
      ip1 = entity.informal_propositions.find { |ip| ip.id == "IP1" }
      expect(ip1.remark_items).not_to be_nil
      expect(ip1.remark_items.first.remarks).to eq(["This is the first informal proposition."])

      ip2 = entity.informal_propositions.find { |ip| ip.id == "IP2" }
      expect(ip2.remark_items).not_to be_nil
      expect(ip2.remark_items.first.remarks).to eq(["This is the second informal proposition."])
    end

    it "attaches wr:WR tags to WhereRules, not as RemarkItems" do
      wr1 = entity.where_rules.find { |wr| wr.id == "WR1" }
      expect(wr1).not_to be_nil
      expect(wr1.remarks).to eq(["The attribute shall be positive."])

      wr2 = entity.where_rules.find { |wr| wr.id == "WR2" }
      expect(wr2).not_to be_nil
      expect(wr2.remarks).to eq(["All items shall satisfy the condition."])
    end

    it "attaches __note to remark_items, not informal_propositions" do
      expect(entity.remark_items.map(&:id)).to eq(["__note"])
    end
  end
end
