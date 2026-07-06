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
       *card(a.owner_end_cardinality),
       a.member_end, a.member_end_type, a.member_end_attribute_name,
       *card(a.member_end_cardinality), a.name]
    end
  end

  def card(cardinality)
    [cardinality&.min, cardinality&.max]
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

    it "drops double quotes from a value containing both quote kinds" do
      # The DSL grammar has no escape sequence, so a value holding both `"`
      # and `'` cannot be emitted losslessly. dsl_quote deletes the double
      # quotes to keep the output parseable — a deliberate tradeoff.
      doc = Lutaml::Uml::Document.new(name: "M")
      doc.title = %q(a "double" and a 'single')

      reparsed = reparse(doc.to_lutaml)

      expect(reparsed.title).to eq("a double and a 'single'")
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
      # Deliberately NON-default keywords: Enum defaults keyword to
      # "enumeration", so asserting the default would pass even if the
      # exporter dropped the keyword entirely.
      src = <<~LUTAML
        diagram D {
          enum Color <<colours>> {
            red
          }
          data_type Money <<valueType>> {
            amount
          }
        }
      LUTAML
      reparsed = reparse(reparse(src).to_lutaml)

      expect(reparsed.enums.first.keyword).to eq("colours")
      expect(reparsed.data_types.first.keyword).to eq("valueType")
    end
  end

  describe "qualified and dotted association names round-trip" do
    it "re-parses shorthand-only names emitted via the block form",
       :aggregate_failures do
      src = <<~LUTAML
        diagram D {
          Foo::Bar --> Baz::Qux
          A#x.y o--> B#other:role [0..*]
        }
      LUTAML
      document = reparse(src)

      reparsed = reparse(document.to_lutaml)

      expect(association_tuples(reparsed)).to eq(association_tuples(document))
      expect(reparsed.associations.first.owner_end).to eq("Foo::Bar")
      expect(reparsed.associations.first.member_end).to eq("Baz::Qux")
    end
  end
end
