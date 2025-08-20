# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::Parsers::Dsl do
  describe "LML and LUTAML file parsing and mapping" do
    def parse_lml(fname)
      File.open(fname) { |f| Lutaml::Uml::Parsers::Dsl.parse(f) }
    end

    describe "parsing test.lutaml for diagram/classes/definitions/attributes" do
      let(:doc) { parse_lml("spec/fixtures/test.lutaml") }

      it "returns a Lutaml::Uml::Document with correct title" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.title).to eq("my diagram").or be_nil
      end

      context "AddressClassProfile class" do
        let(:klass) { doc.classes.find { |c| c.name == "AddressClassProfile" } }

        it "exists and has correct definition" do
          expect(klass).not_to be_nil, "Expected AddressClassProfile class to exist" 
          expect(klass.definition).to include("this is multiline")
        end

        it "has an attribute 'addressClassProfile' with correct type and cardinality" do
          attr = klass.attributes.find { |a| a.name == "addressClassProfile" }
          expect(attr).not_to be_nil, "Expected attribute 'addressClassProfile' to exist"
          expect(attr.type).to eq("CharacterString")
          expect(attr.cardinality).to eq("0..1").or eq({"min"=>"0", "max"=>"1"})
        end
      end

      context "AttributeProfile class" do
        let(:klass2) { doc.classes.find { |c| c.name == "AttributeProfile" } }

        it "exists" do
          expect(klass2).not_to be_nil, "Expected AttributeProfile class to exist"
        end

        it "has an attribute 'imlicistAttributeProfile' with correct type, cardinality, and definition" do
          attr2 = klass2.attributes.find { |a| a.name == "imlicistAttributeProfile" }
          expect(attr2).not_to be_nil, "Expected attribute 'imlicistAttributeProfile' to exist"
          expect(attr2.type).to eq("CharacterString")
          expect(attr2.cardinality).to eq("0..1").or eq({"min"=>"0", "max"=>"1"})
          expect(attr2.definition).to include("this is attribute definition")
        end
      end
    end

    describe "parsing data_s102_check.lml for instances and requires" do
      let(:doc) { parse_lml("spec/fixtures/lml/data_s102_check.lml") }

      it "returns a Lutaml::Uml::Document and includes required file" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.requires).to include("iho_s102_check.lml")
      end

      context "S158Checks instance" do
        let(:inst) { doc.instance }

        it "exists and has correct type" do
          expect(inst).not_to be_nil, "Expected S158Checks instance to exist"
          expect(inst.type).to eq("S158Checks")
        end

        it "has a 'checks' attribute with correct structure and values" do
          checks = inst.attributes.find { |a| a.name == "checks" }
          expect(checks).not_to be_nil, "Expected 'checks' attribute to exist"
          expect(checks.value).to be_a(Array)
          first_check = checks.value.first
          expect(first_check.type).to eq("IhoS102Check::ValidationCheck")
          dev_id_check = first_check.attributes.find { |a| a.name == "dev_id" }
          expect(dev_id_check).not_to be_nil, "Expected 'dev_id' attribute to exist in first check"
          expect(dev_id_check.value).to eq("S102_Dev1001")
        end
      end
    end

    describe "parsing data_s158_metadata.lml for nested instances and lists" do
      let(:doc) { parse_lml("spec/fixtures/lml/data_s158_metadata.lml") }

      it "returns a Lutaml::Uml::Document and has a top-level instance" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.instance).not_to be_nil
      end

      context "top-level instance (meta)" do
        let(:meta) { doc.instance }

        it "has a nested instance (iho) with correct attributes and lists" do
          iho = meta.instance
          expect(iho).not_to be_nil, "Expected nested instance 'iho' to exist"
          doc_number_attr = iho.attributes.find { |a| a.name == "document_number" }
          expect(doc_number_attr).not_to be_nil, "Expected 'document_number' attribute to exist"
          expect(doc_number_attr.value).to eq("S-158:102")

          compliant_standards = iho.attributes.find { |a| a.name == "compliant_standards" }
          expect(compliant_standards).not_to be_nil, "Expected 'compliant_standards' attribute to exist"
          expect(compliant_standards.value).to be_a(Array)
          first_standard = compliant_standards.value.first
          expect(first_standard.type).to eq("CompliantStandard")
          title_attr = first_standard.attributes.find { |a| a.name == "title" }
          expect(title_attr).not_to be_nil, "Expected 'title' attribute to exist in first compliant standard"
          expect(title_attr.value).to eq("S-102 PS")
        end
      end
    end

    it "parses iho_data_models.lml and maps models/classes/attributes" do
      doc = parse_lml("spec/fixtures/lml/iho_data_models.lml")
      expect(doc).to be_a(Lutaml::Uml::Document)
      expect(doc.name).to eq("IhoDataModels")
      klass = doc.classes.find { |c| c.name == "IhoMetadata" }
      expect(klass).not_to be_nil
      expect(klass.attributes.map(&:name)).to include("document_number", "title", "document_type", "edition", "issued_date", "committee", "wg_pt", "compliant_standards")
      attr = klass.attributes.find { |a| a.name == "document_number" }
      expect(attr.type).to eq("String")
      expect(attr.cardinality).to eq("1").or eq({"min"=>"1"})
    end

    describe "parsing iho_s102_check.lml for models/classes/attributes" do
      let(:doc) { parse_lml("spec/fixtures/lml/iho_s102_check.lml") }

      it "returns a Lutaml::Uml::Document with correct name" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.name).to eql("IhoS102Check")
      end

      context "ValidationCheck class" do
        let(:klass) { doc.classes.find { |c| c.name == "ValidationCheck" } }

        it "exists and has correct attributes" do
          expect(klass).not_to be_nil, "Expected ValidationCheck class to exist"
          expect(klass.attributes.map(&:name)).to include(
            "dev_id", "check_id", "classification", "check_message", "check_description", "check_solution"
          )
        end

        it "has 'dev_id' attribute with correct type, cardinality, and properties" do
          attr = klass.attributes.find { |a| a.name == "dev_id" }
          expect(attr).not_to be_nil, "Expected attribute 'dev_id' to exist"
          expect(attr.type).to eq("String")
          expect(attr.cardinality).to eq("1").or eq({"min"=>"1"})
          expect(attr.properties).to include("description" => "Dev ID: Development identifier for the check")
        end
      end
    end

    describe "parsing mixed diagram lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/diagram.lml") }

      it "returns a Lutaml::Uml::Document with correct title" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.title).to eq("my diagram").or be_nil
      end

      context "AddressClassProfile class" do
        let(:klass) { doc.classes.find { |c| c.name == "AddressClassProfile" } }

        it "exists and has correct definition" do
          expect(klass).not_to be_nil, "Expected AddressClassProfile class to exist"
          expect(klass.definition).to include("this is multiline")
        end

        it "has attributes with correct types and cardinalities" do
          attr = klass.attributes.find { |a| a.name == "addressClassProfile" }
          expect(attr).not_to be_nil, "Expected attribute 'addressClassProfile' to exist"
          expect(attr.type).to eq("CharacterString")
          expect(attr.cardinality).to eq("0..1").or eq({"min"=>"0", "max"=>"1"})

          attr2 = klass.attributes.find { |a| a.name == "address" }
          expect(attr2).not_to be_nil, "Expected attribute 'address' to exist"
          expect(attr2.type).to eq("String")
          expect(attr2.cardinality).to eq("1").or eq({"min"=>"1"})
        end
      end

      context "AttributeProfile class" do
        let(:klass2) { doc.classes.find { |c| c.name == "AttributeProfile" } }

        it "exists" do
          expect(klass2).not_to be_nil, "Expected AttributeProfile class to exist"
        end

        it "has an attribute 'imlicistAttributeProfile' with correct type, cardinality, and definition" do
          attr2 = klass2.attributes.find { |a| a.name == "imlicistAttributeProfile" }
          expect(attr2).not_to be_nil, "Expected attribute 'imlicistAttributeProfile' to exist"
          expect(attr2.type).to eq("CharacterString")
          expect(attr2.cardinality).to eq("0..1").or eq({"min"=>"0", "max"=>"1"})
          expect(attr2.definition).to include("this is attribute definition")
        end
      end
    end

    describe "parsing mixed model lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/model.lml") }

      it "returns a Lutaml::Uml::Document with correct name" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.name).to eql("IhoS102Check")
      end

      context "ValidationCheck class" do
        let(:klass) { doc.classes.find { |c| c.name == "ValidationCheck" } }

        it "exists and has correct attributes" do
          expect(klass).not_to be_nil, "Expected ValidationCheck class to exist"
          expect(klass.attributes.map(&:name)).to include("dev_id", "classification", "check_message")
        end

        it "has 'dev_id' and 'classification' attributes with correct types and cardinalities" do
          attr = klass.attributes.find { |a| a.name == "dev_id" }
          expect(attr).not_to be_nil, "Expected attribute 'dev_id' to exist"
          expect(attr.type).to eq("String")
          expect(attr.cardinality).to eq("1").or eq({"min"=>"1"})

          attr2 = klass.attributes.find { |a| a.name == "classification" }
          expect(attr2).not_to be_nil, "Expected attribute 'classification' to exist"
          expect(attr2.type).to eq("Classification")
          expect(attr2.cardinality).to eq("1").or eq({"min"=>"1"})
        end
      end
    end

    context "when parsing mixed_lml/instances.lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/instances.lml") }

      it "parses the document and instance collection" do
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.instances).to be_a(Lutaml::Uml::InstanceCollection)
      end

      it "maps collections correctly" do
        collections = doc.instances.collections
        expect(collections).to be_a(Lutaml::Uml::Collection)
        expect(collections.name).to eq("test_suite_1")
        expect(collections.includes).to eq(["laptop_123", "desktop_1", "desktop_2"])
        expect(collections.validations).to eq(["count >= 3", "all? { |i| i.components.count > 0 }"])
      end

      it "maps imports correctly" do
        imports = doc.instances.imports
        expect(imports.size).to eq(2)
        xml_import = imports.find { |imp| imp.format_type == "xml" }
        expect(xml_import.file).to eq("test_data/products.xml")
        expect(xml_import.attributes.map(&:name)).to include("map_to", "where")
        expect(xml_import.attributes.find { |a| a.name == "map_to" }.value).to eq("Product")
        expect(xml_import.attributes.find { |a| a.name == "where" }.value).to eq("/product")
        csv_import = imports.find { |imp| imp.format_type == "csv" }
        expect(csv_import.file).to eq("test_data/components.csv")
        expect(csv_import.attributes.map(&:name)).to include("map_to", "columns")
      end

      it "maps exports correctly" do
        exports = doc.instances.exports
        expect(exports.size).to eq(2)
        xml_export = exports.find { |exp| exp.format_type == "xml" }
        expect(xml_export.attributes.map(&:name)).to include("file", "indent", "encoding")
        expect(xml_export.attributes.find { |a| a.name == "file" }.value).to eq("output/products.xml")
        expect(xml_export.attributes.find { |a| a.name == "indent" }.value).to eq(true)
        expect(xml_export.attributes.find { |a| a.name == "encoding" }.value).to eq("UTF-8")
        step_export = exports.find { |exp| exp.format_type == "step" }
        expect(step_export.attributes.map(&:name)).to include("file", "reference_format")
        expect(step_export.attributes.find { |a| a.name == "file" }.value).to eq("output/products.stp")
        expect(step_export.attributes.find { |a| a.name == "reference_format" }.value).to eq("#%{id}")
      end

      it "maps product inheritance and template correctly" do
        products = doc.instances.instances.filter { |i| i.type == "Product" }
        base_computer = products.first
        expect(base_computer).not_to be_nil
        components_attr = base_computer.template.find { |a| a.name == "components" }
        expect(components_attr.value).to be_a(Array)
        expect(components_attr.value.first.type).to eq("Component")
        expect(products.last.parent).to eq("base_computer")
      end
    end
  end

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
          .to(eq("Block elements of StandardDocument, adapted from " \
                 "BasicDocument. Another - symbol"))
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
          expect(association.member_end_cardinality).to(eq("min" => "0",
                                                           "max" => "*"))
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
                                      "this is multiline\n    comment with " \
                                      "{} special\n    chars/\n\n    +-|/"]))
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
        "this is attribute definition\nwith multiply lines" \
          "\n{foo} {name}\nend definition"
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
