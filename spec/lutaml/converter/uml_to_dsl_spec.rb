# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Lutaml::Converter::UmlToDsl do
  let(:fixture) { fixtures_path("dsl/diagram_class_assocation.lutaml") }
  let(:document) { Lutaml::Uml::Parsers::Dsl.parse(File.new(fixture)) }

  def reparse(dsl_string)
    file = Tempfile.new(["uml_to_dsl", ".lutaml"])
    file.write(dsl_string)
    file.flush
    Lutaml::Uml::Parsers::Dsl.parse(File.new(file.path))
  ensure
    file&.close
    file&.unlink
  end

  def association_tuples(doc)
    doc.associations.map do |a|
      [a.owner_end, a.owner_end_type, a.owner_end_attribute_name,
       a.member_end, a.member_end_type, a.member_end_attribute_name,
       a.member_end_cardinality&.min, a.member_end_cardinality&.max, a.name]
    end
  end

  describe "Document#to_lutaml" do
    it "emits LutaML DSL that re-parses without error" do
      expect { reparse(document.to_lutaml) }.not_to raise_error
    end

    it "round-trips the document structurally", :aggregate_failures do
      reparsed = reparse(document.to_lutaml)

      expect(reparsed.name).to eq(document.name)
      expect(reparsed.title).to eq(document.title)
      expect(reparsed.classes.map(&:name)).to eq(document.classes.map(&:name))
      expect(reparsed.classes.map { |c| c.attributes.to_a.map(&:name) })
        .to eq(document.classes.map { |c| c.attributes.to_a.map(&:name) })
      expect(association_tuples(reparsed)).to eq(association_tuples(document))
    end

    it "does not mutate the source document" do
      before = association_tuples(document)
      document.to_lutaml
      expect(association_tuples(document)).to eq(before)
    end
  end

  describe "title and caption round-trip" do
    it "preserves titles and captions with special characters",
       :aggregate_failures do
      doc = Lutaml::Uml::Document.new(name: "M")
      doc.title = "Core (v1.2) / urf"
      doc.caption = "needs a \"quote\" inside"

      reparsed = reparse(doc.to_lutaml)

      expect(reparsed.title).to eq("Core (v1.2) / urf")
      expect(reparsed.caption).to eq("needs a \"quote\" inside")
    end
  end

  describe "rich round-trip" do
    let(:fixture) { fixtures_path("dsl/diagram_roundtrip_rich.lutaml") }

    def attribute_tuples(klass)
      klass.attributes.to_a.map do |a|
        [a.name, a.visibility, a.type,
         a.cardinality&.min, a.cardinality&.max, a.definition]
      end
    end

    it "preserves attributes, visibility, types, cardinality and definitions",
       :aggregate_failures do
      reparsed = reparse(document.to_lutaml)

      original = document.classes.map { |c| [c.name, c.modifier, c.definition, attribute_tuples(c)] }
      roundtripped = reparsed.classes.map { |c| [c.name, c.modifier, c.definition, attribute_tuples(c)] }
      expect(roundtripped).to eq(original)
      # guards the attribute-definition emission specifically
      ssn = reparsed.classes.find { |c| c.name == "Person" }.attributes.find { |a| a.name == "ssn" }
      expect(ssn.definition).to eq("Social security number.")
    end

    it "preserves enums, data types and primitives", :aggregate_failures do
      reparsed = reparse(document.to_lutaml)

      expect(reparsed.enums.map { |e| [e.name, e.attributes.to_a.map(&:name)] })
        .to eq(document.enums.map { |e| [e.name, e.attributes.to_a.map(&:name)] })
      expect(reparsed.data_types.map { |d| d.attributes.to_a.map(&:name) })
        .to eq(document.data_types.map { |d| d.attributes.to_a.map(&:name) })
      expect(reparsed.primitives.map(&:name))
        .to eq(document.primitives.map(&:name))
      expect(association_tuples(reparsed)).to eq(association_tuples(document))
    end
  end

  describe "definition escaping round-trip" do
    it "round-trips a definition containing backslashes and braces" do
      tricky = 'a backslash \\ and braces { } and a \\{ combo'
      document = Lutaml::Uml::Document.new(name: "M")
      document.classes = [Lutaml::Uml::Class.new(name: "C", definition: tricky)]

      reparsed = reparse(document.to_lutaml)

      expect(reparsed.classes.first.definition).to eq(tricky)
    end
  end

  describe "classifier keyword round-trip" do
    it "preserves <<keyword>> on enums and data types", :aggregate_failures do
      src = <<~LUTAML
        diagram D {
          enum Color <<enumeration>> {
            red
          }
          data_type Money <<valueType>> {
            amount
          }
        }
      LUTAML
      reparsed = reparse(reparse(src).to_lutaml)

      expect(reparsed.enums.first.keyword).to eq("enumeration")
      expect(reparsed.data_types.first.keyword).to eq("valueType")
    end
  end
end
