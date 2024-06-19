# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Parsers::Dsl do
  describe ".parse" do
    subject(:parse) { described_class.parse(content) }
    subject(:format_parsed_document) do
      Lutaml::Uml::Formatter::Graphviz.new.format_document(parse)
    end

    shared_examples "the correct graphviz formatting" do
      it "does not raise error on graphviz formatting" do
        expect { format_parsed_document }.to_not raise_error
      end
    end

    context "when simple diagram without attributes" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram.lutaml"))
      end

      it "creates Lutaml::Uml::Document object from supplied dsl" do
        expect(parse).to be_instance_of(Lutaml::Uml::Document)
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when diagram with attributes" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_attributes.lutaml"))
      end

      it "creates Lutaml::Uml::Document object and sets its attributes" do
        expect(parse).to be_instance_of(Lutaml::Uml::Document)
        expect(parse.title).to eq("my diagram, another symbols: text.")
        expect(parse.caption)
          .to(eq("Block elements of StandardDocument, adapted from BasicDocument. Another - symbol"))
        expect(parse.fontname).to eq("Arial")
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when multiply classes entries" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_multiply_classes.lutaml"))
      end

      it "creates Lutaml::Uml::Document object and creates dependent classes" do
        classes = parse.classes
        expect(parse).to be_instance_of(Lutaml::Uml::Document)
        expect(parse.classes.length).to eq(4)
        expect(by_name(classes, "NamespacedClass").keyword).to eq("MyNamespace")
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when class with fields" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_class_fields.lutaml"))
      end

      it "creates the correct classes and sets the \
          correct number of attributes" do
        classes = parse.classes
        expect(by_name(classes, "Component").attributes).to be_nil
        expect(by_name(classes, "AddressClassProfile")
                .attributes.length).to eq(1)
        expect(by_name(classes, "AttributeProfile")
                .attributes.length).to eq(13)
        expect(by_name(classes, "AttributeProfile")
                .attributes.map(&:name))
              .to(eq(["imlicistAttributeProfile",
                "attributeProfile",
                "attributeProfile1",
                "privateAttributeProfile",
                "friendlyAttributeProfile",
                "friendlyAttributeProfile1",
                "protectedAttributeProfile",
                "type/text",
                "slashType",
                "application/docbook+xml",
                "application/tei+xml",
                "text/x-asciidoc",
                "application/x-isodoc+xml"]))
      end

      it "creates the correct attributes with the correct visibility" do
        attributes = by_name(parse.classes, "AttributeProfile").attributes
        expect(by_name(attributes, "imlicistAttributeProfile").visibility)
          .to be_nil
        expect(by_name(attributes, "imlicistAttributeProfile").keyword)
          .to be_nil
        expect(by_name(attributes, "attributeProfile").visibility)
          .to eq("public")
        expect(by_name(attributes, "attributeProfile").keyword)
          .to eq("BasicDocument")
        expect(by_name(attributes, "attributeProfile1").visibility)
          .to eq("public")
        expect(by_name(attributes, "attributeProfile1").keyword)
          .to eq("BasicDocument")
        expect(by_name(attributes, "privateAttributeProfile").visibility)
          .to eq("private")
        expect(by_name(attributes, "friendlyAttributeProfile").visibility)
          .to eq("friendly")
        expect(by_name(attributes, "friendlyAttributeProfile").keyword)
          .to eq("Type")
        expect(by_name(attributes, "protectedAttributeProfile").visibility)
          .to eq("protected")
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when association blocks exists" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_class_assocation.lutaml"))
      end

      it "creates the correct number of associations" do
        expect(parse.associations.length).to eq(3)
      end

      context "when bidirectional asscoiation syntax " do
        subject(:association) do
          by_name(parse.associations, "BidirectionalAsscoiation")
        end

        it "creates associations with the correct attributes" do
          expect(association.owner_end_type).to(eq("aggregation"))
          expect(association.member_end_type).to(eq("direct"))
          expect(association.owner_end).to(eq("AddressClassProfile"))
          expect(association.owner_end_attribute_name)
            .to(eq("addressClassProfile"))
          expect(association.member_end).to(eq("AttributeProfile"))
          expect(association.member_end_attribute_name)
            .to(eq("attributeProfile"))
          expect(association.member_end_cardinality).to(eq("min" => "0", "max" => "*"))
        end
      end

      context "when direct asscoiation syntax " do
        subject(:association) do
          by_name(parse.associations, "DirectAsscoiation")
        end

        it "creates associations with the correct attributes" do
          expect(association.owner_end_type).to(be_nil)
          expect(association.member_end_type).to(eq("direct"))
          expect(association.owner_end).to(eq("AddressClassProfile"))
          expect(association.owner_end_attribute_name).to(be_nil)
          expect(association.member_end).to(eq("AttributeProfile"))
          expect(association.member_end_attribute_name)
            .to(eq("attributeProfile"))
          expect(association.member_end_cardinality).to(be_nil)
        end
      end

      context "when reverse asscoiation syntax " do
        subject(:association) do
          by_name(parse.associations, "ReverseAsscoiation")
        end

        it "creates associations with the correct attributes" do
          expect(association.owner_end_type).to(eq("aggregation"))
          expect(association.member_end_type).to(be_nil)
          expect(association.owner_end).to(eq("AddressClassProfile"))
          expect(association.owner_end_attribute_name)
            .to(eq("addressClassProfile"))
          expect(association.member_end).to(eq("AttributeProfile"))
          expect(association.member_end_attribute_name).to(be_nil)
          expect(association.member_end_cardinality).to(be_nil)
        end
      end
    end

    context "when data_types entries" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_data_types.lutaml"))
      end

      it "Generates the correct nodes for enums" do
        enums = parse.enums
        expect(by_name(enums, "MyEnum").attributes).to be_nil
        expect(by_name(enums, "AddressClassProfile")
                .attributes.length).to eq(1)
        expect(by_name(enums, "Profile")
                .attributes.length).to eq(5)
      end

      it "Generates the correct nodes for data_types" do
        data_types = parse.data_types
        expect(by_name(data_types, "Banking Information")
                .attributes.map(&:name))
          .to(eq(["art code", "CCT Number"]))
      end

      it "Generates the correct nodes for primitives" do
        data_types = parse.primitives
        expect(by_name(data_types, "Integer")).to_not be_nil
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when concept model generated lutaml file" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_concept_model.lutaml"))
      end

      it "Generates the correct class/enums/associations list" do
        document = parse
        expect(document.classes.length).to(eq(9))
        expect(document.enums.length).to(eq(3))
        expect(document.associations.length).to(eq(16))
      end

      it "Generates the correct attributes list" do
        attributes = by_name(parse.classes, "ExpressionDesignation").attributes
        expect(attributes.length).to(eq(5))
        expect(attributes.map(&:name))
          .to(eq(%w[text language script pronunciation grammarInfo]))
        expect(attributes.map(&:type))
          .to(eq(["GlossaristTextElementType",
                  "Iso639ThreeCharCode",
                  "Iso15924Code",
                  "LocalizedString",
                  "GrammarInfo"]))
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when include directives is used" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_includes.lutaml"))
      end

      it "includes supplied files into the document" do
        expect(parse.classes.map(&:name))
          .to(eq(%w[Foo Doo Koo AttributeProfile]))
        expect(by_name(parse.classes, "AttributeProfile")
                .attributes.map(&:name))
          .to eq(["imlicistAttributeProfile", "attributeProfile"])
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when include directives is used" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_comments.lutaml"))
      end

      it "create comments for document and classes" do
        expect(parse.comments).to(eq(["My comment",
                                      "this is multiline\n    comment with {} special\n    chars/\n\n    +-|/"]))
        expect(parse.classes.last.comments)
          .to(eq(["this is attribute comment",
                  "this is another comment line\n    with multiply lines"]))
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when defninition directives included" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_definitions.lutaml"))
      end
      let(:class_definition) do
        "this is multiline with `ascidoc`\ncomments\nand list\n{foo} {name}"
      end
      let(:attribute_definition) do
        "this is attribute definition\nwith multiply lines\n{foo} {name}\nend definition"
      end

      it "create comments for document and classes" do
        expect(by_name(parse.classes, "AddressClassProfile").definition)
          .to(eq(class_definition))
        expect(by_name(parse.classes, "AttributeProfile")
                .attributes
                .first
                .definition)
          .to(eq(attribute_definition))
      end

      it_behaves_like "the correct graphviz formatting"
    end

    context "when defninition is blank" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_blank_definion.lutaml"))
      end

      it "successfully renders" do
        expect { parse }.to_not(raise_error)
      end
    end

    context "when there are blank definitions" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_blank_entities.lutaml"))
      end

      it "successfully renders" do
        expect { parse }.to_not(raise_error)
      end
    end

    context "when its a non existing include file" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_non_existing_include.lutaml"))
      end

      it "successfully renders" do
        expect { parse }.to_not(raise_error)
      end
    end

    context "when there are commented preprocessor lines" do
      let(:content) do
        File.new(fixtures_path("dsl/diagram_commented_includes.lutaml"))
      end

      it "successfully renders" do
        expect { parse }.to_not(raise_error)
      end
    end

    context "when broken lutaml file passed" do
      let(:content) do
        File.new(fixtures_path("dsl/broken_diagram.lutaml"))
      end

      it "returns error object and prints line number" do
        expect { described_class.parse(content, {}) }
          .to(raise_error(Lutaml::Uml::Parsers::ParsingError,
              /but got ":" at line 25 char 32/))
      end
    end
  end
end
