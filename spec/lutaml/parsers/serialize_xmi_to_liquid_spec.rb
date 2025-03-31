require "spec_helper"

RSpec.describe Lutaml::XMI::Parsers::XML do
  describe ".serialize_xmi_to_liquid" do
    subject(:output) do
      described_class.serialize_xmi_to_liquid(file)
    end

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
      let(:first_package) { output.packages.first }

      it "parses xml file into Lutaml::XMI::RootDrop object" do
        expect(output).to(be_instance_of(Lutaml::XMI::RootDrop))
      end

      it "correctly parses model name" do
        expect(output.name).to(eq("EA_Model"))
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
        root_package = output.packages.first
        expect(root_package.diagrams.length).to(eq(1))
        expect(root_package.diagrams.map(&:name))
          .to(eq(["Starter Class Diagram"]))
        expect(root_package.diagrams.map(&:definition))
          .to(eq(["aada\n"]))
      end
    end

    context "when parsing xmi with generalization" do
      let(:file) { File.new(fixtures_path("plateau_all_packages_export.xmi")) }

      it "should output attributes correctly" do
        test_package = output.packages.first.packages[2].packages[9]
        gen_obj = test_package.classes[3].generalization
        expect(test_package.name).to eq("bldg")
        expect(gen_obj.name).to eq("Building")

        expect(gen_obj.general.attributes[0][:name]).to eq("class")
        expect(gen_obj.general.attributes[0][:id]).to eq(
          "EAID_FDC435D4_544B_4122_BEA1_7C0B55136938",
        )
        expect(gen_obj.general.attributes[0][:type]).to eq("gml::CodeType")
        expect(gen_obj.general.attributes[0][:xmi_id]).to eq(
          "EAJava_gml__CodeType",
        )
        expect(gen_obj.general.attributes[0][:is_derived]).to eq(nil)
        expect(gen_obj.general.attributes[0][:association]).to eq(nil)
        expect(gen_obj.general.attributes[0][:definition]).to eq(
          "建築物の形態による区分。コードリスト(&lt;&lt;Building_class.xml&gt;&gt;)より選択する。",
        )
        expect(gen_obj.general.attributes[28][:association]).to eq(
          "EAID_99ADD620_BC08_4adc_80A1_A8EB2A1B2E2F",
        )

        expect(gen_obj.inherited_props[0].name).to eq("description")
        expect(gen_obj.inherited_props[0].type).to eq("gml::StringOrRefType")
        expect(gen_obj.inherited_props[0].type_ns).to eq(nil)
        expect(gen_obj.inherited_props[0].upper_klass).to eq("gml")
        expect(gen_obj.inherited_props[0].gen_name).to eq("_Feature")
        expect(gen_obj.inherited_props[0].name_ns).to eq("gml")
        expect(gen_obj.inherited_props[0].association).to eq(nil)

        expect(gen_obj.inherited_assoc_props[0].association).to eq(
          "EAID_98F26EAF_7E3C_48b2_AAE7_4769CF1AAFD6",
        )
      end
    end

    context "when parsing xmi with generalization and guidance yaml" do
      let(:file) { File.new(fixtures_path("plateau_all_packages_export.xmi")) }
      let(:guidance) { YAML.load_file(fixtures_path("guidance/guidance.yaml")) }

      subject(:output) do
        described_class.serialize_xmi_to_liquid(file, guidance)
      end

      it "should output attributes correctly" do
        test_package = output.packages.first.packages[2].packages[9]
        test_klass = test_package.classes[3]
        gen_obj = test_package.classes[3].generalization
        expect(test_package.name).to eq("bldg")
        expect(gen_obj.name).to eq("Building")
        expect(test_package.absolute_path).to eq(
          "::EA_Model::Conceptual Models::CityGML2.0::bldg",
        )
        expect(test_klass.name).to eq("Building")
        expect(test_klass.absolute_path).to eq(
          "::EA_Model::Conceptual Models::CityGML2.0::bldg::Building",
        )

        expect(gen_obj.general.attributes[0][:name]).to eq("class")
        expect(gen_obj.general.attributes[0][:id]).to eq(
          "EAID_FDC435D4_544B_4122_BEA1_7C0B55136938",
        )
        expect(gen_obj.general.attributes[0][:type]).to eq("gml::CodeType")
        expect(gen_obj.general.attributes[0][:xmi_id]).to eq(
          "EAJava_gml__CodeType",
        )
        expect(gen_obj.general.attributes[0][:is_derived]).to eq(nil)
        expect(gen_obj.general.attributes[0][:association]).to eq(nil)
        expect(gen_obj.general.attributes[0][:definition]).to eq(
          "建築物の形態による区分。コードリスト(&lt;&lt;Building_class.xml&gt;&gt;)より選択する。",
        )
        expect(gen_obj.general.attributes[28][:association]).to eq(
          "EAID_99ADD620_BC08_4adc_80A1_A8EB2A1B2E2F",
        )

        expect(gen_obj.inherited_props[2].name).to eq("boundedBy")
        expect(gen_obj.inherited_props[2].used?).to eq(false)
        expect(gen_obj.inherited_props[2].guidance).to eq("この属性は使用されていません。\n")

        expect(gen_obj.inherited_props[0].name).to eq("description")
        expect(gen_obj.inherited_props[0].type).to eq("gml::StringOrRefType")
        expect(gen_obj.inherited_props[0].type_ns).to eq(nil)
        expect(gen_obj.inherited_props[0].upper_klass).to eq("gml")
        expect(gen_obj.inherited_props[0].gen_name).to eq("_Feature")
        expect(gen_obj.inherited_props[0].name_ns).to eq("gml")
        expect(gen_obj.inherited_props[0].association).to eq(nil)
        expect(gen_obj.inherited_props[0].used?).to eq(true)
        expect(gen_obj.inherited_props[0].guidance).to eq(nil)

        expect(gen_obj.inherited_assoc_props[0].association).to eq(
          "EAID_98F26EAF_7E3C_48b2_AAE7_4769CF1AAFD6",
        )
      end
    end

    context "when parsing xmi with generalization and sorted props" do
      let(:file) { File.new(fixtures_path("plateau_all_packages_export.xmi")) }

      it "should output attributes correctly" do
        test_package = output.packages.first.packages[1].packages[0]
          .packages[1].classes[144]
        gen_obj = test_package.generalization
        expect(test_package.name).to eq("TrafficFacility")

        expect(
          gen_obj.inherited_assoc_props.map do |p|
            "#{p.name_ns}:#{p.name}[#{p.gen_name}]"
          end,
        ).to eq(
          [
            "core:core::外部参照[_CityObject]",
            "gen:_genericAttribute[_CityObject]",
            "urf:lod0MultiCurve[_UrbanFunction]",
            "urf:lod0MultiSurface[_UrbanFunction]",
            "urf:lod1MultiSurface[_UrbanFunction]",
            "urf:lod0MultiPoint[_UrbanFunction]",
            "uro:dataQualityAttribute[_UrbanFunction]",
            "urf:table[_UrbanFunction]",
            "urf:attributes[_UrbanFunction]",
            "uro:keyValuePairAttribute[_UrbanFunction]",
            "urf:urbanParkAttribute[Zone]",
            "urf:boundary[Zone]",
            "urf:threeDimensionalExtent[UrbanFacility]",
          ],
        )

        expect(
          gen_obj.sorted_inherited_assoc_props.map do |p|
            "#{p.name_ns}:#{p.name}[#{p.gen_name}]"
          end,
        ).to eq(
          [
            "core:core::外部参照[_CityObject]",
            "gen:_genericAttribute[_CityObject]",
            "urf:attributes[_UrbanFunction]",
            "urf:lod0MultiCurve[_UrbanFunction]",
            "urf:lod0MultiPoint[_UrbanFunction]",
            "urf:lod0MultiSurface[_UrbanFunction]",
            "urf:lod1MultiSurface[_UrbanFunction]",
            "urf:table[_UrbanFunction]",
            "uro:dataQualityAttribute[_UrbanFunction]",
            "uro:keyValuePairAttribute[_UrbanFunction]",
            "urf:boundary[Zone]",
            "urf:urbanParkAttribute[Zone]",
            "urf:threeDimensionalExtent[UrbanFacility]",
          ],
        )
      end
    end
  end
end
