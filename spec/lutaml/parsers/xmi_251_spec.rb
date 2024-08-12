require "spec_helper"

RSpec.describe Lutaml::XMI::Parsers::XML do
  describe ".parse" do
    subject(:parse) { described_class.parse(file) }

    context "when parsing xmi 2013 with uml 2013" do
      let(:file) { File.new(fixtures_path("ea-xmi-2.5.1.xmi")) }

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
      let(:expected_enum_xmi_ids) do
        ["EAID_E497ABDA_05EF_416a_A461_03535864970D"]
      end
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
        [
          "ClassificationType[0..*],",
          "RequirementSubpart[0..*],",
          "String[0..1],",
          "String,",
          "RequirementSubpart[0..*],",
          "String[0..*],",
          "boolean[0..1],",
          "boolean[0..1],",
          "String[0..1],",
          "RequirementSubpart[0..*],",
          "String[0..1],",
          "String[0..1],",
          "ObligationType[1..*],",
          "BibliographicItem[0..1],",
          "RequirementSubpart[0..*],",
          "String[0..1],",
          "RequirementSubpart[0..*],",
          "String[0..1],",
          "FormattedString[0..1],",
          "String[0..1],",
          "boolean[0..1],",
          "RequirementSubpart[0..*],",
        ]
      end

      let(:expected_association_names) do
        %w[
          RequirementType
        ]
      end
      let(:first_package) { parse.packages.first }

      it "parses xml file into Lutaml::Uml::Node::Document object" do
        expect(parse).to(be_instance_of(Lutaml::Uml::Document))
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
          .to match_array([])
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
        @xmi_root_model = Xmi::Sparx::SparxRoot.parse_xml(xml_content)
        new_parser.send(:parse, @xmi_root_model)
      end

      it ".lookup_entity_name" do
        owner_end = new_parser.send(
          :lookup_entity_name, "EAID_E50B0756_49E6_4725_AC7B_382A34BB8935"
        )
        expect(owner_end).to eq("verification")
      end

      it ".fetch_element" do
        e = new_parser.send(
          :fetch_element, "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA"
        )
        expect(e).to be_instance_of(Xmi::Sparx::SparxElement)
        expect(e.idref).to eq("EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA")
      end

      it ".doc_node_attribute_value" do
        val = new_parser.send(
          :doc_node_attribute_value,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", "stereotype"
        )
        expect(val).to eq("Bibliography")

        val = new_parser.send(
          :doc_node_attribute_value,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", "isAbstract"
        )
        expect(val).to eq(false)

        val = new_parser.send(
          :doc_node_attribute_value,
          "EAID_69271FAE_C52F_42ab_81B4_126CE0BF4663", "documentation"
        )
        expect(val).to eq(
          "RequirementType is a generic category,&#xA;which is agnostic as " \
          "to obligation.&#xA;Requirement, Recommendation, " \
          "Permission&#xA;set a specific obligation, although this&#xA;can " \
          "be overridden.".gsub("&#xA;", "\n"),
        )
      end

      it ".select_all_packaged_elements" do
        all_elements = []
        new_parser.send(
          :select_all_packaged_elements, all_elements,
          @xmi_root_model.model, nil
        )
        expect(all_elements.count).to eq(15)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement)).to be(true)
        end
      end

      it ".select_all_packaged_elements with type uml:Association" do
        all_elements = []
        new_parser.send(
          :select_all_packaged_elements, all_elements,
          @xmi_root_model.model, "uml:Association"
        )
        expect(all_elements.count).to eq(5)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement)).to be(true)
          expect(e.type).to eq("uml:Association")
        end
      end

      it ".all_packaged_elements" do
        all_elements = new_parser.send(:all_packaged_elements)
        expect(all_elements.count).to eq(37)
        all_elements.each do |e|
          expect(e.is_a?(Xmi::Uml::PackagedElement)).to be(true)
        end
      end

      it ".serialize_model_enums" do
        val = new_parser.send(
          :serialize_model_enums, @xmi_root_model.model.packaged_element.first
        )

        expect(val).to eq(
          [{
            xmi_id: "EAID_E497ABDA_05EF_416a_A461_03535864970D",
            name: "ObligationType",
            stereotype: "enumeration",
            definition: nil,
            values: [
              {
                definition: nil,
                name: "requirement",
                type: nil,
              },
              {
                definition: nil,
                name: "recommendation",
                type: nil,
              },
              {
                definition: nil,
                name: "permission",
                type: nil,
              },
            ],
          }],
        )
      end

      it ".serialize_model_classes" do
        val = new_parser.send(
          :serialize_model_classes,
          @xmi_root_model.model.packaged_element.first, @xmi_root_model.model
        )
        expect(val.count).to eq(8)
        expect(val.first[:xmi_id]).to eq(
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA",
        )
        expect(val.first[:name]).to eq("BibliographicItem")
      end

      it ".serialize_model_data_types" do
        val = new_parser.send(
          :serialize_model_data_types, @xmi_root_model.model
        )
        expect(val).to eq([])
      end

      it ".serialize_model_diagrams" do
        val = new_parser.send(
          :serialize_model_diagrams,
          "EAPK_C799E047_A10F_4203_9E22_9C47183CED98",
        )
        expect(val.count).to eq(1)
        expect(val).to eq([{
                            xmi_id: "EAID_FB7118FD_7DE4_4dac_8E43_1F55CD195957",
                            name: "Starter Class Diagram",
                            definition: "aada\n",
                          }])
      end

      it ".serialize_model_associations without association" do
        val = new_parser.send(
          :serialize_model_associations,
          "EAPK_C799E047_A10F_4203_9E22_9C47183CED98",
        )
        expect(val).to eq(nil)
      end

      it ".serialize_model_associations with associations" do
        val = new_parser.send(
          :serialize_model_associations,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA",
        )

        expect(val).to eq(
          [{
            xmi_id: "EAID_2CA98919_831B_4182_BBC2_C2EAF17FEF60",
            member_end: "RequirementType",
            member_end_type: "aggregation",
            member_end_cardinality: { "min" => nil, "max" => nil },
            member_end_attribute_name: "RequirementType",
            member_end_xmi_id: "EAID_C1155D80_E68B_46d5_ADE5_F5639486163D",
            owner_end: "BibliographicItem",
            owner_end_xmi_id: "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA",
            definition: nil,
          }],
        )
      end

      it ".fetch_connector" do
        val = new_parser.send(
          :fetch_connector,
          "EAID_2CA98919_831B_4182_BBC2_C2EAF17FEF60",
        )
        expect(val).to be_instance_of(Xmi::Sparx::SparxConnector)
        expect(val.idref).to eq("EAID_2CA98919_831B_4182_BBC2_C2EAF17FEF60")
      end

      it ".fetch_definition_node_value" do
        val = new_parser.send(
          :fetch_definition_node_value,
          "EAID_2CA98919_831B_4182_BBC2_C2EAF17FEF60", "source"
        )
        expect(val).to eq(nil)
      end

      it ".serialize_class_operations" do
        val = new_parser.send(
          :serialize_class_operations,
          @xmi_root_model.model.packaged_element.first,
        )
        expect(val).to eq([])
      end

      it ".serialize_class_constraints" do
        val = new_parser.send(
          :serialize_class_constraints,
          "EAID_2CA98919_831B_4182_BBC2_C2EAF17FEF60",
        )
        expect(val).to eq([])
      end

      it ".serialize_owned_type" do
        link = @xmi_root_model.extension.elements.element[1].links
          .association.first
        val = new_parser.send(
          :serialize_owned_type,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", link, "start"
        )
        expect(val).to eq("RequirementType")
      end

      it ".serialize_member_end" do
        link = @xmi_root_model.extension.elements.element[1].links
          .association.first
        val = new_parser.send(
          :serialize_member_end,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", link
        )
        expect(val).to eq([
                            "RequirementType",
                            "EAID_C1155D80_E68B_46d5_ADE5_F5639486163D",
                          ])
      end

      it ".serialize_member_type" do
        link = @xmi_root_model.extension.elements.element[1].links
          .association.first
        val = new_parser.send(
          :serialize_member_type,
          "EAID_D832D6D8_0518_43f7_9166_7A4E3E8605AA", link, "start"
        )
        expect(val).to eq([
                            "RequirementType",
                            "aggregation",
                            { "max" => nil, "min" => nil },
                            "RequirementType",
                            "EAID_C1155D80_E68B_46d5_ADE5_F5639486163D",
                          ])
      end

      it ".fetch_assoc_connector" do
        link = @xmi_root_model.extension.elements.element[1].links
          .association.first
        val = new_parser.send(:fetch_assoc_connector, link.id, "target")
        expect(val).to eq([{ "max" => nil, "min" => nil }, "BibliographicItem"])
      end

      it ".generalization_association if link.start == owner_xmi_id" do
        link_element = @xmi_root_model.extension.elements.element.select do |e|
          !e.links.nil? && !e.links.generalization.empty?
        end.first
        link = link_element.links.generalization.first
        val = new_parser.send(
          :generalization_association,
          "EAID_82354CDC_EACB_402f_8C2B_FD627B7416E7", link
        )
        expect(val).to eq([
                            "RequirementType",
                            "inheritance",
                            { "max" => nil, "min" => nil },
                            nil,
                            "EAID_C1155D80_E68B_46d5_ADE5_F5639486163D",
                          ])
      end

      it ".generalization_association if link.start != owner_xmi_id" do
        link_element = @xmi_root_model.extension.elements.element.select do |e|
          !e.links.nil? && !e.links.generalization.empty?
        end.first
        link = link_element.links.generalization.first
        val = new_parser.send(
          :generalization_association,
          "EAID_C1155D80_E68B_46d5_ADE5_F5639486163D", link
        )
        expect(val).to eq([
                            "Permission",
                            "generalization",
                            nil,
                            nil,
                            "EAID_82354CDC_EACB_402f_8C2B_FD627B7416E7",
                          ])
      end

      it ".cardinality_min_max_value with min 0" do
        val = new_parser.send(:cardinality_min_max_value, 0, 5)
        expect(val).to eq({ "max" => 5, "min" => "C" })
      end

      it ".cardinality_min_max_value with min 1" do
        val = new_parser.send(:cardinality_min_max_value, 1, 5)
        expect(val).to eq({ "max" => 5, "min" => "M" })
      end

      it ".fetch_owned_attribute_node" do
        val = new_parser.send(:fetch_owned_attribute_node, "EAJava_String_")
        expect(val).to eq([nil, nil])
      end
    end
  end
end
