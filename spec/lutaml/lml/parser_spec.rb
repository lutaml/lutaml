# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Lml::Parser do
  describe "LML and LUTAML file parsing and mapping" do
    def parse_lml(fname)
      File.open(fname) { |f| Lutaml::Lml::Parser.parse(f) }
    end

    describe "parsing test.lutaml for diagram/classes/definitions/attributes" do
      let(:doc) { parse_lml("spec/fixtures/test.lutaml") }

      it "returns a Lutaml::Lml::Document with correct title" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(attr.cardinality.min).to eq("0")
          expect(attr.cardinality.max).to eq("1")
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
          expect(attr2.cardinality.min).to eq("0")
          expect(attr2.cardinality.max).to eq("1")
          expect(attr2.definition).to include("this is attribute definition")
        end
      end
    end

    describe "parsing data_s102_check.lml for instances and requires" do
      let(:doc) { parse_lml("spec/fixtures/lml/data_s102_check.lml") }

      it "returns a Lutaml::Lml::Document and includes required file" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(checks.instances).to be_a(Array)
          first_check = checks.instances.first
          expect(first_check.type).to eq("IhoS102Check::ValidationCheck")
          dev_id_check = first_check.attributes.find { |a| a.name == "dev_id" }
          expect(dev_id_check).not_to be_nil, "Expected 'dev_id' attribute to exist in first check"
          expect(dev_id_check.value).to eq("S102_Dev1001")
        end
      end
    end

    describe "parsing data_s158_metadata.lml for nested instances and lists" do
      let(:doc) { parse_lml("spec/fixtures/lml/data_s158_metadata.lml") }

      it "returns a Lutaml::Lml::Document and has a top-level instance" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(compliant_standards.instances).to be_a(Array)
          first_standard = compliant_standards.instances.first
          expect(first_standard.type).to eq("CompliantStandard")
          title_attr = first_standard.attributes.find { |a| a.name == "title" }
          expect(title_attr).not_to be_nil, "Expected 'title' attribute to exist in first compliant standard"
          expect(title_attr.value).to eq("S-102 PS")
        end
      end
    end

    it "parses iho_data_models.lml and maps models/classes/attributes" do
      doc = parse_lml("spec/fixtures/lml/iho_data_models.lml")
      expect(doc).to be_a(Lutaml::Lml::Document)
      expect(doc.name).to eq("IhoDataModels")
      klass = doc.classes.find { |c| c.name == "IhoMetadata" }
      expect(klass).not_to be_nil
      expect(klass.attributes.map(&:name)).to include("document_number", "title", "document_type", "edition", "issued_date", "committee", "wg_pt", "compliant_standards")
      attr = klass.attributes.find { |a| a.name == "document_number" }
      expect(attr.type).to eq("String")
      expect(attr.cardinality.min).to eq("1")
    end

    describe "parsing iho_s102_check.lml for models/classes/attributes" do
      let(:doc) { parse_lml("spec/fixtures/lml/iho_s102_check.lml") }

      it "returns a Lutaml::Lml::Document with correct name" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(attr.cardinality.min).to eq("1")
          expect(attr.properties.find { |p| p.name == "description" }.value).to eq("Dev ID: Development identifier for the check")
        end
      end
    end

    describe "parsing mixed diagram lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/diagram.lml") }

      it "returns a Lutaml::Lml::Document with correct title" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(attr.cardinality.max).to eq("1")

          attr2 = klass.attributes.find { |a| a.name == "address" }
          expect(attr2).not_to be_nil, "Expected attribute 'address' to exist"
          expect(attr2.type).to eq("String")
          expect(attr2.cardinality.min).to eq("1")
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
          expect(attr2.cardinality.min).to eq("0")
          expect(attr2.cardinality.max).to eq("1")
          expect(attr2.definition).to include("this is attribute definition")
        end
      end
    end

    describe "parsing mixed model lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/model.lml") }

      it "returns a Lutaml::Lml::Document with correct name" do
        expect(doc).to be_a(Lutaml::Lml::Document)
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
          expect(attr.cardinality.min).to eq("1")

          attr2 = klass.attributes.find { |a| a.name == "classification" }
          expect(attr2).not_to be_nil, "Expected attribute 'classification' to exist"
          expect(attr2.type).to eq("Classification")
          expect(attr2.cardinality.min).to eq("1")
        end
      end
    end

    context "when parsing mixed_lml/instances.lml" do
      let(:doc) { parse_lml("spec/fixtures/mixed_lml/instances.lml") }

      it "parses the document and instance collection" do
        expect(doc).to be_a(Lutaml::Lml::Document)
        expect(doc.instances).to be_a(Lutaml::Lml::InstanceCollection)
      end

      it "maps collections correctly" do
        collections = doc.instances.collections
        expect(collections).to be_a(Lutaml::Lml::Collection)
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
        expect(components_attr.instances).to be_a(Array)
        expect(components_attr.instances.first.type).to eq("Component")
        expect(products.last.parent).to eq("base_computer")
      end
    end
  end
end
