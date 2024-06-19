require "spec_helper"

RSpec.describe Lutaml::XMI::Parsers::XML do
  describe ".parse" do
    subject(:parse) { described_class.parse(file) }

    context "when parsing xmi 2013 with uml 2013" do
      let(:file) { File.new(fixtures_path("ea-xmi-2.5.1.xmi")) }

      let(:expected_first_package_package_names) do
        [
          "BibliographicItem",
          nil,
          "Block",
          nil,
          "ClassificationType",
          nil,
          "ObligationType",
          nil,
          "Permission",
          "Recommendation",
          "Requirement",
          "RequirementSubpart",
          nil,
          "RequirementType",
        ]
      end
      let(:expected_class_names) do
        %w[
          BibliographicItem
          Block
          ClassificationType
          Permission
          Recommendation
          Requirement
          RequirementSubpart
          RequirementType
        ]
      end
      let(:expected_class_xmi_ids) do
        %w[
          EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA
          EAID_10AD8D60_9972_475a_AB7E_FA40212D5297
          EAID_30B0131C_804F_4f67_8B6F_35DF5ABD8E78
          EAID_82354CDC_EACB_402f_8C2B_FD627B7416E7
          EAID_AD7320C2_FEE6_4352_8D56_F2C8562B6153
          EAID_2AC20C81_1E83_400d_B098_BAB784395E06
          EAID_035D8176_5E9E_42c8_B447_64411AE96F57
          EAID_C1155D80_E68B_46d5_ADE5_F5639486163D
        ]
      end
      let(:expected_enum_names) { ["ObligationType"] }
      let(:expected_enum_xmi_ids) { ["EAID_E497ABDA_05EF_416a_A461_03535864970D"] }
      let(:expected_attributes_names) do
        %w[
          classification
          description
          filename
          id
          import
          inherit
          keep-lines-together
          keep-with-next
          label
          measurement-target
          model
          number
          obligation
          references
          specification
          subject
          subrequirement
          subsequence
          title
          type
          unnumbered
          verification
        ]
      end
      let(:expected_attributes_types) do
        %w[
          EAJava_ClassificationType_0..___
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_String_
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..___
          EAJava_boolean_0..1__
          EAJava_boolean_0..1__
          EAJava_String_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_String_0..1__
          EAJava_ObligationType_1..___
          EAJava_BibliographicItem_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_RequirementSubpart_0..___
          EAJava_String_0..1__
          EAJava_FormattedString_0..1__
          EAJava_String_0..1__
          EAJava_boolean_0..1__
          EAJava_RequirementSubpart_0..___
        ]
      end

      let(:expected_association_names) do
        %w[
          RequirementType
        ]
      end
      let(:first_package) { parse.packages.first }

      it "parses xml file into Lutaml::Uml::Node::Document object" do
        expect(parse).to(be_instance_of(::Lutaml::Uml::Document))
      end

      it "correctly parses model name" do
        expect(parse.name).to(eq("EA_Model"))
      end

      it "correctly parses first package" do
        expect(first_package.name)
          .to(eq("requirement type class diagram"))
      end

      it "correctly parses package tree" do
        expect(first_package.packages.map(&:name))
          .to(eq(expected_first_package_package_names))
      end

      it "correctly parses package classes" do
        expect(first_package.classes.map(&:name)).to(eq(expected_class_names))
        expect(first_package.classes.map(&:xmi_id))
          .to(eq(expected_class_xmi_ids))
      end

      it "correctly parses entities of enums type" do
        expect(first_package.enums.map(&:name)).to(eq(expected_enum_names))
        expect(first_package.enums.map(&:xmi_id)).to(eq(expected_enum_xmi_ids))
      end

      it "correctly parses entities and attributes for class" do
        klass = first_package.classes.find do |entity|
          entity.name == "RequirementType"
        end

        expect(klass.attributes.map(&:name)).to(eq(expected_attributes_names))
        expect(klass.attributes.map(&:type)).to(eq(expected_attributes_types))
      end

      it "correctly parses associations for class" do
        klass = first_package.classes.find do |entity|
          entity.name == "Block"
        end

        expect(klass.associations.map(&:member_end).compact)
          .to(eq(expected_association_names))
      end

      it "correctly parses diagrams for package" do
        root_package = parse.packages.first
        expect(root_package.diagrams.length).to(eq(1))
        expect(root_package.diagrams.map(&:name))
          .to(eq(["Starter Class Diagram"]))
        expect(root_package.diagrams.map(&:definition))
          .to(eq(["aada"]))
      end
    end
  end

  describe ".new" do
    subject(:new_parser) { described_class.new }

    context "when parsing xmi 2013 with uml 2013" do
      let(:file) { File.new(fixtures_path("ea-xmi-2.5.1.xmi")) }

      before do
        xml_content = File.read(file)
        @xmi_root_model = Xmi::Sparx::SparxRoot2013.from_xml(xml_content)
        new_parser.send(:parse, @xmi_root_model)
      end

      it ".lookup_entity_name" do
        owner_end = new_parser.send(:lookup_entity_name, "EAID_E50B0756_49E6_4725_AC7B_382A34BB8935")
        expect(owner_end).to eq("verification")
      end

      it ".fetch_element" do
        e = new_parser.send(:fetch_element, "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA")
        expect(e).to be_instance_of(Xmi::Sparx::SparxElement)
        expect(e.idref).to eq("EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA")
      end

      it ".doc_node_attribute_value" do
        val = new_parser.send(:doc_node_attribute_value, "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", "stereotype")
        expect(val).to eq("Bibliography")

        val = new_parser.send(:doc_node_attribute_value, "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", "isAbstract")
        expect(val).to eq(false)

        val = new_parser.send(:doc_node_attribute_value, "EAID_69271FAE_C52F_42ab_81B4_126CE0BF4663", "documentation")
        expect(val).to eq("RequirementType is a generic category,&#xA;which is agnostic as to obligation.&#xA;Requirement, Recommendation, Permission&#xA;set a specific obligation, although this&#xA;can be overridden.".gsub(/&#xA;/, "\n"))
      end

      it ".select_all_packaged_elements" do
        all_elements = []
        new_parser.send(:select_all_packaged_elements, all_elements, @xmi_root_model.model, nil)
        expect(all_elements.count).to eq(15)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement) || e.is_a?(Xmi::Uml::PackagedElement2013)).to be(true)
        end
      end

      it ".select_all_packaged_elements with type uml:Association" do
        all_elements = []
        new_parser.send(:select_all_packaged_elements, all_elements, @xmi_root_model.model, "uml:Association")
        expect(all_elements.count).to eq(5)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement) || e.is_a?(Xmi::Uml::PackagedElement2013)).to be(true)
          expect(e.type).to eq("uml:Association")
        end
      end

      it ".all_packaged_elements" do
        all_elements = new_parser.send(:all_packaged_elements)
        expect(all_elements.count).to eq(37)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement) || e.is_a?(Xmi::Uml::PackagedElement2013)).to be(true)
        end
      end
    end
  end
end
