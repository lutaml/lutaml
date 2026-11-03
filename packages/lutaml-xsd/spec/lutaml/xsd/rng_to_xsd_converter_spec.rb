# frozen_string_literal: true

require "spec_helper"
require "rng"
require "lutaml/xsd/rng_to_xsd_converter"

RSpec.describe Lutaml::Xsd::RngToXsdConverter do
  describe "#convert" do
    let(:fixture_path) do
      "spec/fixtures/metanorma-model-iso-grammars/bsi.rnc"
    end

    let(:grammar) { Rng.parse_file(fixture_path) }
    let(:converter) { described_class.new(grammar, file_path: fixture_path) }
    let(:schema) { converter.convert }

    it "returns a Schema object" do
      expect(schema).to be_a(Lutaml::Xml::Schema::Xsd::Schema)
    end

    it "produces complex types" do
      expect(schema.complex_type.length).to eq(170)
    end

    it "includes complex types in the included paths" do
      names = schema.complex_type.map(&:name)
      expect(names).to include("Content-Section")
    end

    it "includes complex type Clause-Section" do
      complex_type = schema.complex_type.find do |ct|
        ct.name == "Clause-Section"
      end
      expect(complex_type.name).to eq("Clause-Section")

      attr = complex_type.attribute.first
      expect(attr).to be_a(Lutaml::Xml::Schema::Xsd::Attribute)
      expect(attr.name).to eq("type")

      attr_group = complex_type.attribute_group.first
      expect(attr_group).to be_a(Lutaml::Xml::Schema::Xsd::AttributeGroup)
      expect(attr_group.ref).to eq("Section-Attributes")
    end

    it "includes complex type section-title_type" do
      complex_type = schema.complex_type.find do |ct|
        ct.name == "section-title_type"
      end
      expect(complex_type.name).to eq("section-title_type")
      expect(complex_type.mixed).to eq(true)
    end

    it "produces simple types" do
      expect(schema.simple_type.length).to eq(13)
    end

    it "produces elements" do
      expect(schema.element.length).to eq(203)
    end

    it "produces groups (including groups in the included paths)" do
      expect(schema.group.length).to eq(237)
    end

    it "produces attribute_groups (including groups in the included paths)" do
      expect(schema.attribute_group.length).to eq(44)
      admonition = schema.attribute_group.find do |ag|
        ag.name == "AdmonitionAttributes"
      end
      expect(admonition).not_to be_nil
      expect(admonition.attribute.length).to eq(1)
      expect(admonition.attribute.first.name).to eq("target")
    end

    it "includes 7 choices in the sections content model" do
      sections_el = schema.element.find { |el| el.name == "sections" }
      sections_ct = schema.complex_type.find { |ct| ct.name == sections_el.type }
      expect(sections_ct.sequence.choice.length).to eq(7)
      expect(sections_ct.sequence.group.length).to eq(1)
      expect(sections_ct.sequence.element.length).to eq(1)
    end
  end

  describe "named pattern resolution" do
    # Helper to parse RNC string into a grammar and convert it
    def parse_and_convert(rnc_content)
      require "tempfile"

      Tempfile.create(["test", ".rnc"]) do |f|
        f.write(rnc_content)
        f.flush
        grammar = Rng.parse_file(f.path)
        converter = Lutaml::Xsd::RngToXsdConverter.new(grammar, file_path: f.path)
        converter.convert
      end
    end

    context "when a named pattern wraps a single element with a different name" do
      let(:rnc) do
        <<~RNC
          element root {
            (ext_toc & element email { text })
          }

          ext_toc = element name { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("name")
      end

      it "creates a schema-level group for the named pattern" do
        names = schema.group.map(&:name)
        expect(names).to include("ext_toc")
      end

      it "resolves the named pattern to an element ref inside interleave/all" do
        root = schema.element.find { |e| e.name == "root" }
        expect(root).not_to be_nil

        all = root.complex_type.all
        expect(all).not_to be_nil

        # The all should contain element refs, not group refs
        all.element.each do |el|
          expect(el).to be_a(Lutaml::Xml::Schema::Xsd::Element)
        end

        # The named pattern reference should resolve to an element ref
        name_ref = all.element.find { |el| el.ref == "name" }
        expect(name_ref).not_to be_nil
        expect(name_ref.ref).to eq("name")

        # There should NOT be a group ref to "ext_toc" inside all
        expect(all.element.any? { |el| el.ref == "ext_toc" }).to be false
      end

      it "produces valid XSD output" do
        expect { schema.to_formatted_xml }.not_to raise_error
      end
    end

    context "when a named pattern wraps a single element with a matching name" do
      let(:rnc) do
        <<~RNC
          element root {
            (foo & element bar { text })
          }

          foo = element foo { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("foo")
      end

      it "resolves the named pattern to an element ref inside interleave/all" do
        root = schema.element.find { |e| e.name == "root" }
        all = root.complex_type.all

        foo_ref = all.element.find { |el| el.ref == "foo" }
        expect(foo_ref).not_to be_nil
      end
    end

    context "when a named pattern is referenced directly (not inside interleave)" do
      let(:rnc) do
        <<~RNC
          element root {
            ext_toc
          }

          ext_toc = element name { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "promotes the element to top-level" do
        names = schema.element.map(&:name)
        expect(names).to include("name")
      end

      it "creates a group for the named pattern" do
        names = schema.group.map(&:name)
        expect(names).to include("ext_toc")
      end

      it "resolves to an element ref in the content model" do
        root = schema.element.find { |e| e.name == "root" }
        seq = root.complex_type.sequence

        name_ref = seq.element.find { |el| el.ref == "name" }
        expect(name_ref).not_to be_nil
      end
    end

    context "when multiple defines wrap elements with the same name (collision)" do
      let(:rnc) do
        <<~RNC
          element root {
            (a_ref | b_ref)
          }

          a_ref = element item { text }
          b_ref = element item { text }
        RNC
      end

      subject(:schema) { parse_and_convert(rnc) }

      it "does not promote colliding elements to top-level" do
        # "item" should NOT be a top-level element (there are two defines
        # wrapping elements named "item", so neither gets promoted)
        names = schema.element.map(&:name)
        expect(names).not_to include("item")
      end

      it "creates groups for both defines" do
        names = schema.group.map(&:name)
        expect(names).to include("a_ref", "b_ref")
      end
    end
  end
end
