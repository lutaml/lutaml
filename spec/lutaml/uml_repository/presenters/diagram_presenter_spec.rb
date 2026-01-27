# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/presenters/diagram_presenter"

RSpec.describe Lutaml::UmlRepository::Presenters::DiagramPresenter do
  let(:repository) do
    double("Repository",
           classes_index: [],
           packages_index: [],
           associations_index: [])
  end

  let(:diagram) do
    double("Diagram",
           name: "Test Diagram",
           diagram_type: "Class",
           package_name: "TestPackage",
           diagram_objects: [],
           diagram_links: [])
  end

  let(:presenter) { described_class.new(diagram, repository) }

  describe "#initialize" do
    it "stores diagram reference" do
      expect(presenter.element).to eq(diagram)
    end

    it "stores repository reference" do
      expect(presenter.repository).to eq(repository)
    end

    it "accepts config_path option" do
      presenter_with_config = described_class
        .new(diagram, repository, config_path: "custom/config.yml")
      expect(presenter_with_config.config_path).to eq("custom/config.yml")
    end

    it "creates layout engine" do
      expect(presenter.instance_variable_get(:@layout_engine)).to be_a(Lutaml::Ea::Diagram::LayoutEngine)
    end

    it "defaults config_path to nil" do
      expect(presenter.config_path).to be_nil
    end
  end

  describe "#svg_output" do
    it "generates SVG output" do
      allow(diagram).to receive(:diagram_objects).and_return([])
      allow(diagram).to receive(:diagram_links).and_return([])

      svg = presenter.svg_output
      expect(svg).to be_a(String)
      expect(svg).to include("<svg")
    end

    it "passes config_path to renderer" do
      presenter_with_config = described_class
        .new(diagram, repository, config_path: "test/config.yml")
      allow(diagram).to receive(:diagram_objects).and_return([])
      allow(diagram).to receive(:diagram_links).and_return([])

      svg = presenter_with_config.svg_output
      expect(svg).to include("<svg")
    end

    it "accepts rendering options" do
      allow(diagram).to receive(:diagram_objects).and_return([])
      allow(diagram).to receive(:diagram_links).and_return([])

      svg = presenter.svg_output(padding: 30, background_color: "#f5f5f5")
      expect(svg).to include("<svg")
    end

    it "returns complete SVG string" do
      allow(diagram).to receive(:diagram_objects).and_return([])
      allow(diagram).to receive(:diagram_links).and_return([])

      svg = presenter.svg_output
      expect(svg).to start_with("<?xml")
      expect(svg).to end_with("</svg>\n")
    end
  end

  describe "#elements" do
    it "returns array of element data" do
      allow(diagram).to receive(:diagram_objects).and_return([])

      elements = presenter.elements
      expect(elements).to be_an(Array)
    end

    it "calls build_elements_data" do
      allow(diagram).to receive(:diagram_objects).and_return([])
      expect(presenter).to receive(:build_elements_data).and_call_original

      presenter.elements
    end
  end

  describe "#connectors" do
    it "returns array of connector data" do
      allow(diagram).to receive(:diagram_links).and_return([])

      connectors = presenter.connectors
      expect(connectors).to be_an(Array)
    end

    it "calls build_connectors_data" do
      allow(diagram).to receive(:diagram_objects).and_return([])
      allow(diagram).to receive(:diagram_links).and_return([])
      expect(presenter).to receive(:build_connectors_data).and_call_original

      presenter.connectors
    end
  end

  describe "#to_text" do
    it "generates text representation" do
      text = presenter.to_text
      expect(text).to be_a(String)
    end

    it "includes diagram name" do
      text = presenter.to_text
      expect(text).to include("Test Diagram")
    end

    it "includes diagram type" do
      text = presenter.to_text
      expect(text).to include("Class")
    end

    it "includes package name" do
      text = presenter.to_text
      expect(text).to include("TestPackage")
    end

    it "includes element count" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      text = presenter.to_text
      expect(text).to include("Elements:")
      expect(text).to include("2")
    end

    it "includes connector count" do
      allow(diagram).to receive(:diagram_links).and_return([double, double,
                                                            double])
      text = presenter.to_text
      expect(text).to include("Connectors:")
      expect(text).to include("3")
    end

    it "handles unknown package name" do
      allow(diagram).to receive(:package_name).and_return(nil)
      text = presenter.to_text
      expect(text).to include("Unknown")
    end
  end

  describe "#to_table_row" do
    it "returns hash with type, name, details" do
      row = presenter.to_table_row
      expect(row).to be_a(Hash)
      expect(row).to have_key(:type)
      expect(row).to have_key(:name)
      expect(row).to have_key(:details)
    end

    it "sets type to Diagram" do
      row = presenter.to_table_row
      expect(row[:type]).to eq("Diagram")
    end

    it "includes diagram name" do
      row = presenter.to_table_row
      expect(row[:name]).to eq("Test Diagram")
    end

    it "includes diagram type and count in details" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      row = presenter.to_table_row
      expect(row[:details]).to include("Class")
      expect(row[:details]).to include("2")
    end

    it "handles unnamed diagram" do
      allow(diagram).to receive(:name).and_return(nil)
      row = presenter.to_table_row
      expect(row[:name]).to eq("(unnamed)")
    end
  end

  describe "#to_hash" do
    it "returns hash representation" do
      hash = presenter.to_hash
      expect(hash).to be_a(Hash)
    end

    it "includes all diagram properties" do
      allow(diagram).to receive(:diagram_objects).and_return([double])
      allow(diagram).to receive(:diagram_links).and_return([double])

      hash = presenter.to_hash
      expect(hash[:type]).to eq("Diagram")
      expect(hash[:name]).to eq("Test Diagram")
      expect(hash[:diagram_type]).to eq("Class")
      expect(hash[:package_name]).to eq("TestPackage")
      expect(hash[:elements_count]).to eq(1)
      expect(hash[:connectors_count]).to eq(1)
    end
  end

  describe "private methods" do
    describe "#build_elements_data" do
      context "with diagram_objects" do
        let(:mock_class) do
          double("Class",
                 name: "TestClass",
                 stereotype: "entity",
                 attributes: [],
                 operations: [])
        end

        let(:diagram_object) do
          double("DiagramObject",
                 object_xmi_id: "CLASS_001",
                 left: 100,
                 top: 50,
                 right: 220,
                 bottom: 130,
                 style: nil)
        end

        before do
          allow(diagram)
            .to receive(:diagram_objects).and_return([diagram_object])
          allow(repository).to receive(:classes_index).and_return([mock_class])
          allow(mock_class).to receive(:xmi_id).and_return("CLASS_001")
        end

        it "converts each diagram_object to element data" do
          elements = presenter.send(:build_elements_data)
          expect(elements).to be_an(Array)
          expect(elements.size).to eq(1)
        end

        it "looks up UML element by XMI ID" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:name]).to eq("TestClass")
        end

        it "converts EA coordinates to SVG" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:x]).to eq(100)
          expect(elements.first[:y]).to eq(50)
          expect(elements.first[:width]).to eq(120)
          expect(elements.first[:height]).to eq(80)
        end

        it "extracts element name" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:name]).to eq("TestClass")
        end

        it "determines element type" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:type]).to be_a(String)
        end

        it "extracts stereotype" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:stereotype]).to eq("entity")
        end

        it "extracts attributes" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:attributes]).to be_an(Array)
        end

        it "extracts operations" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:operations]).to be_an(Array)
        end

        it "includes original element" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:element]).to eq(mock_class)
        end

        it "includes original diagram_object" do
          elements = presenter.send(:build_elements_data)
          expect(elements.first[:diagram_object]).to eq(diagram_object)
        end

        it "filters out nil elements when lookup fails" do
          allow(repository).to receive(:classes_index).and_return([])
          elements = presenter.send(:build_elements_data)
          expect(elements).to be_empty
        end
      end

      context "without diagram_objects" do
        before do
          allow(diagram).to receive(:diagram_objects).and_return(nil)
        end

        it "returns empty array" do
          elements = presenter.send(:build_elements_data)
          expect(elements).to eq([])
        end
      end
    end

    describe "#build_connectors_data" do
      context "with diagram_links" do
        let(:mock_association) do
          double("Association",
                 class: double(name: "Lutaml::Uml::Association"),
                 member_end: [])
        end

        let(:diagram_link) do
          double("DiagramLink",
                 connector_xmi_id: "ASSOC_001",
                 geometry: "SX=0;SY=0;EX=0;EY=0;",
                 style: "SOID=OBJ1;EOID=OBJ2;",
                 hidden: false)
        end

        before do
          allow(diagram).to receive(:diagram_objects).and_return([])
          allow(diagram).to receive(:diagram_links).and_return([diagram_link])
          allow(repository)
            .to receive(:associations_index).and_return([mock_association])
          allow(mock_association).to receive(:xmi_id).and_return("ASSOC_001")
        end

        it "converts each diagram_link to connector data" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors).to be_an(Array)
          expect(connectors.size).to eq(1)
        end

        it "looks up connector by XMI ID" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:element]).to eq(mock_association)
        end

        it "determines connector type" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:type]).to eq("association")
        end

        it "includes geometry from diagram_link" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:geometry]).to eq("SX=0;SY=0;EX=0;EY=0;")
        end

        it "includes original element" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:element]).to eq(mock_association)
        end

        it "includes original diagram_link" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:diagram_link]).to eq(diagram_link)
        end

        it "filters out hidden connectors" do
          allow(diagram_link).to receive(:hidden).and_return(true)
          connectors = presenter.send(:build_connectors_data)
          expect(connectors).to be_empty
        end

        it "handles missing connector gracefully" do
          allow(repository).to receive(:associations_index).and_return([])
          connectors = presenter.send(:build_connectors_data)
          expect(connectors.first[:type]).to eq("association") # default type
        end
      end

      context "without diagram_links" do
        before do
          allow(diagram).to receive(:diagram_links).and_return(nil)
        end

        it "returns empty array" do
          connectors = presenter.send(:build_connectors_data)
          expect(connectors).to eq([])
        end
      end
    end

    describe "#parse_diagram_link_style" do
      it "parses SOID from style string" do
        result = presenter.send(:parse_diagram_link_style,
                                "SOID=12345;EOID=67890;")
        expect(result[:soid]).to eq("12345")
      end

      it "parses EOID from style string" do
        result = presenter.send(:parse_diagram_link_style,
                                "SOID=12345;EOID=67890;")
        expect(result[:eoid]).to eq("67890")
      end

      it "handles nil style string" do
        result = presenter.send(:parse_diagram_link_style, nil)
        expect(result).to eq({})
      end

      it "handles empty style string" do
        result = presenter.send(:parse_diagram_link_style, "")
        expect(result).to eq({})
      end

      it "handles malformed style string" do
        result = presenter.send(:parse_diagram_link_style, "INVALID;SOID=123;")
        expect(result[:soid]).to eq("123")
      end

      it "ignores unknown properties" do
        result = presenter.send(:parse_diagram_link_style,
                                "UNKNOWN=999;SOID=123;")
        expect(result).not_to have_key(:unknown)
        expect(result[:soid]).to eq("123")
      end
    end

    describe "#extract_ea_id" do
      let(:diagram_object_with_duid) do
        double("DiagramObject", style: "NSL=0;DUID=ABC123;BCol=123;")
      end

      it "extracts DUID from diagram object style" do
        ea_id = presenter.send(:extract_ea_id, diagram_object_with_duid)
        expect(ea_id).to eq("ABC123")
      end

      it "returns nil for missing style" do
        object_without_style = double("DiagramObject")
        allow(object_without_style)
          .to receive(:respond_to?).with(:style).and_return(false)

        ea_id = presenter.send(:extract_ea_id, object_without_style)
        expect(ea_id).to be_nil
      end

      it "returns nil for nil style" do
        object_with_nil_style = double("DiagramObject", style: nil)
        ea_id = presenter.send(:extract_ea_id, object_with_nil_style)
        expect(ea_id).to be_nil
      end

      it "returns nil for missing DUID" do
        object_without_duid = double("DiagramObject", style: "NSL=0;BCol=123;")
        ea_id = presenter.send(:extract_ea_id, object_without_duid)
        expect(ea_id).to be_nil
      end
    end

    describe "#find_element_by_xmi_id" do
      let(:mock_class) { double("Class", xmi_id: "CLASS_001") }
      let(:mock_package) { double("Package", xmi_id: "PKG_001") }

      before do
        allow(repository).to receive(:classes_index).and_return([mock_class])
        allow(repository).to receive(:packages_index).and_return([mock_package])
      end

      it "finds element in classes_index" do
        element = presenter.send(:find_element_by_xmi_id, "CLASS_001")
        expect(element).to eq(mock_class)
      end

      it "finds element in packages_index" do
        element = presenter.send(:find_element_by_xmi_id, "PKG_001")
        expect(element).to eq(mock_package)
      end

      it "returns nil when not found" do
        element = presenter.send(:find_element_by_xmi_id, "NOT_FOUND")
        expect(element).to be_nil
      end

      it "returns nil for nil xmi_id" do
        element = presenter.send(:find_element_by_xmi_id, nil)
        expect(element).to be_nil
      end

      it "returns nil when repository is nil" do
        presenter_without_repo = described_class.new(diagram, nil)
        element = presenter_without_repo.send(:find_element_by_xmi_id,
                                              "CLASS_001")
        expect(element).to be_nil
      end
    end

    describe "#find_connector_by_xmi_id" do
      let(:mock_association) { double("Association", xmi_id: "ASSOC_001") }
      let(:mock_generalization) { double("Generalization", xmi_id: "GEN_001") }
      let(:mock_class_with_gen) do
        double("Class", generalization: mock_generalization)
      end

      before do
        allow(repository)
          .to receive(:associations_index).and_return([mock_association])
        allow(repository)
          .to receive(:classes_index).and_return([mock_class_with_gen])
        allow(mock_class_with_gen)
          .to receive(:respond_to?).with(:generalization).and_return(true)
        allow(mock_generalization)
          .to receive(:respond_to?).with(:xmi_id).and_return(true)
      end

      it "finds connector in associations_index" do
        connector = presenter.send(:find_connector_by_xmi_id, "ASSOC_001")
        expect(connector).to eq(mock_association)
      end

      it "finds generalization in class" do
        connector = presenter.send(:find_connector_by_xmi_id, "GEN_001")
        expect(connector).to eq(mock_generalization)
      end

      it "handles array of generalizations" do
        gen_array = [mock_generalization]
        allow(mock_class_with_gen)
          .to receive(:generalization).and_return(gen_array)

        connector = presenter.send(:find_connector_by_xmi_id, "GEN_001")
        expect(connector).to eq(mock_generalization)
      end

      it "finds association in class" do
        mock_class_assoc = double("Association", xmi_id: "CLASS_ASSOC")
        mock_class_with_assoc = double("Class",
                                       associations: [mock_class_assoc])
        allow(repository)
          .to receive(:classes_index).and_return([mock_class_with_assoc])
        allow(mock_class_with_assoc)
          .to receive(:respond_to?).with(:generalization).and_return(false)
        allow(mock_class_with_assoc)
          .to receive(:generalization).and_return(nil)
        allow(mock_class_with_assoc)
          .to receive(:respond_to?).with(:associations).and_return(true)
        allow(mock_class_assoc)
          .to receive(:respond_to?).with(:xmi_id).and_return(true)

        connector = presenter.send(:find_connector_by_xmi_id, "CLASS_ASSOC")
        expect(connector).to eq(mock_class_assoc)
      end

      it "returns nil when not found" do
        allow(repository).to receive(:associations_index).and_return([])
        allow(repository).to receive(:classes_index).and_return([])

        connector = presenter.send(:find_connector_by_xmi_id, "NOT_FOUND")
        expect(connector).to be_nil
      end
    end

    describe "#find_connector_target" do
      let(:elements_map) do
        { "TARGET_ID" => { id: "TARGET_ID", name: "Target" } }
      end

      it "uses target property when available" do
        connector = double("Connector", target: "TARGET_ID")
        allow(connector).to receive(:respond_to?).with(:target).and_return(true)

        target = presenter.send(:find_connector_target, connector, elements_map)
        expect(target[:id]).to eq("TARGET_ID")
      end

      it "uses supplier property when available" do
        connector = double("Connector", supplier: "TARGET_ID")
        allow(connector)
          .to receive(:respond_to?).with(:target).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:supplier).and_return(true)

        target = presenter.send(:find_connector_target, connector, elements_map)
        expect(target[:id]).to eq("TARGET_ID")
      end

      it "uses general property when available" do
        connector = double("Connector", general: "TARGET_ID")
        allow(connector)
          .to receive(:respond_to?).with(:target).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:supplier).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:general).and_return(true)

        target = presenter.send(:find_connector_target, connector, elements_map)
        expect(target[:id]).to eq("TARGET_ID")
      end

      it "uses second member_end when available" do
        connector = double("Connector", member_end: ["SRC_ID", "TARGET_ID"])
        allow(connector)
          .to receive(:respond_to?).with(:target).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:supplier).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:general).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:member_end).and_return(true)

        target = presenter.send(:find_connector_target, connector, elements_map)
        expect(target[:id]).to eq("TARGET_ID")
      end

      it "returns nil when not found" do
        connector = double("Connector")
        allow(connector).to receive(:respond_to?).and_return(false)

        target = presenter.send(:find_connector_target, connector, elements_map)
        expect(target).to be_nil
      end
    end

    describe "#find_connector_source" do
      let(:elements_map) do
        { "SOURCE_ID" => { id: "SOURCE_ID", name: "Source" } }
      end

      it "uses source property when available" do
        connector = double("Connector", source: "SOURCE_ID")
        allow(connector).to receive(:respond_to?).with(:source).and_return(true)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source[:id]).to eq("SOURCE_ID")
      end

      it "uses client property when available" do
        connector = double("Connector", client: "SOURCE_ID")
        allow(connector)
          .to receive(:respond_to?).with(:source).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:client).and_return(true)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source[:id]).to eq("SOURCE_ID")
      end

      it "uses specific property when available" do
        connector = double("Connector", specific: "SOURCE_ID")
        allow(connector)
          .to receive(:respond_to?).with(:source).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:client).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:specific).and_return(true)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source[:id]).to eq("SOURCE_ID")
      end

      it "uses owner_end property when available" do
        connector = double("Connector", owner_end: "SOURCE_ID")
        allow(connector)
          .to receive(:respond_to?).with(:source).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:client).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:specific).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:owner_end).and_return(true)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source[:id]).to eq("SOURCE_ID")
      end

      it "uses first member_end when available" do
        connector = double("Connector", member_end: ["SOURCE_ID", "TARGET_ID"])
        allow(connector)
          .to receive(:respond_to?).with(:source).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:client).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:specific).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:owner_end).and_return(false)
        allow(connector)
          .to receive(:respond_to?).with(:member_end).and_return(true)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source[:id]).to eq("SOURCE_ID")
      end

      it "returns nil when not found" do
        connector = double("Connector")
        allow(connector).to receive(:respond_to?).and_return(false)

        source = presenter.send(:find_connector_source, connector, elements_map)
        expect(source).to be_nil
      end
    end

    describe "#determine_element_type" do
      it "returns 'datatype' for DataType class" do
        element = double("Element", class: double(name: "Lutaml::Uml::DataType"))
        type = presenter.send(:determine_element_type, element)
        expect(type).to eq("datatype")
      end

      it "returns 'enum' for Enum class" do
        element = double("Element", class: double(name: "Lutaml::Uml::Enum"))
        type = presenter.send(:determine_element_type, element)
        expect(type).to eq("enum")
      end

      it "returns 'class' for Class class" do
        element = double("Element", class: double(name: "Lutaml::Uml::Class"))
        type = presenter.send(:determine_element_type, element)
        expect(type).to eq("class")
      end

      it "returns 'package' for Package class" do
        element = double("Element", class: double(name: "Lutaml::Uml::Package"))
        type = presenter.send(:determine_element_type, element)
        expect(type).to eq("package")
      end

      it "defaults to 'class' for unknown types" do
        element = double("Element", class: double(name: "Unknown::Type"))
        type = presenter.send(:determine_element_type, element)
        expect(type).to eq("class")
      end
    end

    describe "#determine_connector_type" do
      it "returns 'generalization' for Generalization class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Generalization"))
        type = presenter.send(:determine_connector_type, connector)
        expect(type).to eq("generalization")
      end

      it "returns 'association' for Association class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Association"))
        type = presenter.send(:determine_connector_type, connector)
        expect(type).to eq("association")
      end

      it "returns 'dependency' for Dependency class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Dependency"))
        type = presenter.send(:determine_connector_type, connector)
        expect(type).to eq("dependency")
      end

      it "returns 'realization' for Realization class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Realization"))
        type = presenter.send(:determine_connector_type, connector)
        expect(type).to eq("realization")
      end

      it "defaults to 'association' for unknown types" do
        connector = double("Connector", class: double(name: "Unknown::Type"))
        type = presenter.send(:determine_connector_type, connector)
        expect(type).to eq("association")
      end
    end

    describe "#extract_stereotype" do
      it "extracts stereotype string" do
        element = double("Element", stereotype: "entity")
        allow(element)
          .to receive(:respond_to?).with(:stereotype).and_return(true)

        stereotype = presenter.send(:extract_stereotype, element)
        expect(stereotype).to eq("entity")
      end

      it "handles array of stereotypes" do
        element = double("Element", stereotype: ["entity", "feature"])
        allow(element)
          .to receive(:respond_to?).with(:stereotype).and_return(true)

        stereotype = presenter.send(:extract_stereotype, element)
        expect(stereotype).to eq("entity")
      end

      it "returns nil when not available" do
        element = double("Element")
        allow(element)
          .to receive(:respond_to?).with(:stereotype).and_return(false)

        stereotype = presenter.send(:extract_stereotype, element)
        expect(stereotype).to be_nil
      end

      it "returns nil for nil stereotype" do
        element = double("Element", stereotype: nil)
        allow(element)
          .to receive(:respond_to?).with(:stereotype).and_return(true)

        stereotype = presenter.send(:extract_stereotype, element)
        expect(stereotype).to be_nil
      end
    end

    describe "#extract_attributes" do
      let(:mock_attribute) do
        double("Attribute", name: "id", type: "Integer", visibility: "public")
      end

      it "extracts array of attribute data" do
        element = double("Element", attributes: [mock_attribute])
        allow(element)
          .to receive(:respond_to?).with(:attributes).and_return(true)
        allow(mock_attribute)
          .to receive(:respond_to?).with(:visibility).and_return(true)

        attributes = presenter.send(:extract_attributes, element)
        expect(attributes).to be_an(Array)
        expect(attributes.size).to eq(1)
      end

      it "includes name, type, visibility" do
        element = double("Element", attributes: [mock_attribute])
        allow(element)
          .to receive(:respond_to?).with(:attributes).and_return(true)
        allow(mock_attribute)
          .to receive(:respond_to?).with(:visibility).and_return(true)

        attributes = presenter.send(:extract_attributes, element)
        expect(attributes.first[:name]).to eq("id")
        expect(attributes.first[:type]).to eq("Integer")
        expect(attributes.first[:visibility]).to eq("public")
      end

      it "returns empty array when not available" do
        element = double("Element")
        allow(element)
          .to receive(:respond_to?).with(:attributes).and_return(false)

        attributes = presenter.send(:extract_attributes, element)
        expect(attributes).to eq([])
      end

      it "returns empty array for nil attributes" do
        element = double("Element", attributes: nil)
        allow(element)
          .to receive(:respond_to?).with(:attributes).and_return(true)

        attributes = presenter.send(:extract_attributes, element)
        expect(attributes).to eq([])
      end
    end

    describe "#extract_operations" do
      let(:mock_parameter) do
        double("Parameter", name: "value", type: "String")
      end

      let(:mock_operation) do
        double("Operation",
               name: "setValue",
               visibility: "public",
               return_type: "void",
               owned_parameter: [mock_parameter])
      end

      it "extracts array of operation data" do
        element = double("Element", operations: [mock_operation])
        allow(element)
          .to receive(:respond_to?).with(:operations).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:visibility).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:return_type).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(true)

        operations = presenter.send(:extract_operations, element)
        expect(operations).to be_an(Array)
        expect(operations.size).to eq(1)
      end

      it "includes name, visibility, return_type, parameters" do
        element = double("Element", operations: [mock_operation])
        allow(element)
          .to receive(:respond_to?).with(:operations).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:visibility).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:return_type).and_return(true)
        allow(mock_operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(true)

        operations = presenter.send(:extract_operations, element)
        expect(operations.first[:name]).to eq("setValue")
        expect(operations.first[:visibility]).to eq("public")
        expect(operations.first[:return_type]).to eq("void")
        expect(operations.first[:parameters]).to be_an(Array)
      end

      it "returns empty array when not available" do
        element = double("Element")
        allow(element)
          .to receive(:respond_to?).with(:operations).and_return(false)

        operations = presenter.send(:extract_operations, element)
        expect(operations).to eq([])
      end
    end

    describe "#extract_parameters" do
      let(:mock_parameter) do
        double("Parameter", name: "value", type: "String")
      end

      it "extracts array of parameter data" do
        operation = double("Operation", owned_parameter: [mock_parameter])
        allow(operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(true)

        parameters = presenter.send(:extract_parameters, operation)
        expect(parameters).to be_an(Array)
        expect(parameters.size).to eq(1)
      end

      it "includes name and type" do
        operation = double("Operation", owned_parameter: [mock_parameter])
        allow(operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(true)

        parameters = presenter.send(:extract_parameters, operation)
        expect(parameters.first[:name]).to eq("value")
        expect(parameters.first[:type]).to eq("String")
      end

      it "returns empty array when not available" do
        operation = double("Operation")
        allow(operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(false)

        parameters = presenter.send(:extract_parameters, operation)
        expect(parameters).to eq([])
      end

      it "returns empty array for nil parameters" do
        operation = double("Operation", owned_parameter: nil)
        allow(operation)
          .to receive(:respond_to?).with(:owned_parameter).and_return(true)

        parameters = presenter.send(:extract_parameters, operation)
        expect(parameters).to eq([])
      end
    end
  end

  describe "DiagramRendererWrapper" do
    let(:layout_engine) { Lutaml::Ea::Diagram::LayoutEngine.new }
    let(:diagram_data) do
      {
        name: "Test",
        elements: [
          { id: "1", x: 0, y: 0, width: 100, height: 80 },
        ],
        connectors: [
          { id: "c1", type: "association" },
        ],
      }
    end
    let(:wrapper) do
      described_class::DiagramRendererWrapper.new(diagram_data, layout_engine)
    end

    describe "#initialize" do
      it "stores diagram_data" do
        expect(wrapper.diagram_data).to eq(diagram_data)
      end

      it "stores elements from diagram_data" do
        expect(wrapper.elements).to eq(diagram_data[:elements])
      end

      it "stores connectors from diagram_data" do
        expect(wrapper.connectors).to eq(diagram_data[:connectors])
      end

      it "calculates bounds using layout_engine" do
        expect(wrapper.bounds).to be_a(Hash)
        expect(wrapper.bounds).to have_key(:x)
        expect(wrapper.bounds).to have_key(:y)
        expect(wrapper.bounds).to have_key(:width)
        expect(wrapper.bounds).to have_key(:height)
      end

      it "handles empty elements" do
        empty_data = { name: "Empty", elements: [], connectors: [] }
        empty_wrapper = described_class::DiagramRendererWrapper
          .new(empty_data, layout_engine)
        expect(empty_wrapper.elements).to eq([])
      end

      it "handles nil elements" do
        nil_data = { name: "Nil", elements: nil, connectors: nil }
        nil_wrapper = described_class::DiagramRendererWrapper
          .new(nil_data, layout_engine)
        expect(nil_wrapper.elements).to eq([])
      end
    end

    describe "accessors" do
      it "provides diagram_data accessor" do
        expect(wrapper).to respond_to(:diagram_data)
      end

      it "provides bounds accessor" do
        expect(wrapper).to respond_to(:bounds)
      end

      it "provides elements accessor" do
        expect(wrapper).to respond_to(:elements)
      end

      it "provides connectors accessor" do
        expect(wrapper).to respond_to(:connectors)
      end
    end
  end
end
