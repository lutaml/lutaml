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

  before do
    allow(diagram).to receive_messages(diagram_objects: [],
                                       diagram_links: [])
  end

  describe "#initialize" do
    it { expect(presenter.element).to eq(diagram) }
    it { expect(presenter.repository).to eq(repository) }

    it "accepts config_path option" do
      pwc = described_class.new(diagram, repository,
                                config_path: "custom/config.yml")
      expect(pwc.config_path).to eq("custom/config.yml")
    end

    it "creates layout engine" do
      expect(presenter.instance_variable_get(:@layout_engine))
        .to be_a(Lutaml::Ea::Diagram::LayoutEngine)
    end

    it { expect(presenter.config_path).to be_nil }
  end

  describe "#svg_output" do
    it { expect(presenter.svg_output).to be_a(String) }
    it { expect(presenter.svg_output).to include("<svg") }

    it "passes config_path to renderer" do
      pwc = described_class.new(diagram, repository,
                                config_path: "test/config.yml")
      expect(pwc.svg_output).to include("<svg")
    end

    it "accepts rendering options" do
      svg = presenter.svg_output(padding: 30, background_color: "#f5f5f5")
      expect(svg).to include("<svg")
    end

    it { expect(presenter.svg_output).to start_with("<?xml") }
    it { expect(presenter.svg_output).to end_with("</svg>\n") }
  end

  describe "#elements" do
    it { expect(presenter.elements).to be_an(Array) }

    it "calls build_elements_data" do
      expect(presenter).to receive(:build_elements_data).and_call_original
      presenter.elements
    end
  end

  describe "#connectors" do
    it { expect(presenter.connectors).to be_an(Array) }

    it "calls build_connectors_data" do
      expect(presenter).to receive(:build_connectors_data).and_call_original
      presenter.connectors
    end
  end

  describe "#to_text" do
    let(:text) { presenter.to_text }

    it { expect(text).to be_a(String) }
    it { expect(text).to include("Test Diagram") }
    it { expect(text).to include("Class") }
    it { expect(text).to include("TestPackage") }

    it "includes element count" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      expect(presenter.to_text).to include("Elements:")
    end

    it "shows 2 elements" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      expect(presenter.to_text).to include("2")
    end

    it "includes connector count" do
      allow(diagram).to receive(:diagram_links)
        .and_return([double, double, double])
      expect(presenter.to_text).to include("Connectors:")
    end

    it "shows 3 connectors" do
      allow(diagram).to receive(:diagram_links)
        .and_return([double, double, double])
      expect(presenter.to_text).to include("3")
    end

    it "handles unknown package name" do
      allow(diagram).to receive(:package_name).and_return(nil)
      expect(presenter.to_text).to include("Unknown")
    end
  end

  describe "#to_table_row" do
    let(:row) { presenter.to_table_row }

    it { expect(row).to be_a(Hash) }
    it { expect(row).to have_key(:type) }
    it { expect(row).to have_key(:name) }
    it { expect(row).to have_key(:details) }
    it { expect(row[:type]).to eq("Diagram") }
    it { expect(row[:name]).to eq("Test Diagram") }

    it "includes diagram type in details" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      expect(row[:details]).to include("Class")
    end

    it "includes element count in details" do
      allow(diagram).to receive(:diagram_objects).and_return([double, double])
      expect(row[:details]).to include("2")
    end

    it "handles unnamed diagram" do
      allow(diagram).to receive(:name).and_return(nil)
      expect(presenter.to_table_row[:name]).to eq("(unnamed)")
    end
  end

  describe "#to_hash" do
    before do
      allow(diagram).to receive_messages(diagram_objects: [double],
                                         diagram_links: [double])
    end

    let(:hash) { presenter.to_hash }

    it { expect(hash).to be_a(Hash) }
    it { expect(hash[:type]).to eq("Diagram") }
    it { expect(hash[:name]).to eq("Test Diagram") }
    it { expect(hash[:diagram_type]).to eq("Class") }
    it { expect(hash[:package_name]).to eq("TestPackage") }
    it { expect(hash[:elements_count]).to eq(1) }
    it { expect(hash[:connectors_count]).to eq(1) }
  end

  describe "private methods" do
    describe "#build_elements_data" do
      context "with diagram_objects" do
        let(:mock_class) do
          double("Class", name: "TestClass", stereotype: "entity",
                          attributes: [], operations: [])
        end

        let(:diagram_object) do
          double("DiagramObject", object_xmi_id: "CLASS_001",
                                  left: 100, top: 50, right: 220, bottom: 130, style: nil)
        end

        let(:elements) { presenter.send(:build_elements_data) }

        before do
          allow(diagram).to receive(:diagram_objects)
            .and_return([diagram_object])
          allow(repository).to receive(:classes_index)
            .and_return([mock_class])
          allow(mock_class).to receive(:xmi_id).and_return("CLASS_001")
        end

        it { expect(elements).to be_an(Array) }
        it { expect(elements.size).to eq(1) }
        it { expect(elements.first[:name]).to eq("TestClass") }
        it { expect(elements.first[:x]).to eq(100) }
        it { expect(elements.first[:y]).to eq(50) }
        it { expect(elements.first[:width]).to eq(120) }
        it { expect(elements.first[:height]).to eq(80) }
        it { expect(elements.first[:type]).to be_a(String) }
        it { expect(elements.first[:stereotype]).to eq("entity") }
        it { expect(elements.first[:attributes]).to be_an(Array) }
        it { expect(elements.first[:operations]).to be_an(Array) }
        it { expect(elements.first[:element]).to eq(mock_class) }
        it { expect(elements.first[:diagram_object]).to eq(diagram_object) }

        it "filters nil elements when lookup fails" do
          allow(repository).to receive(:classes_index).and_return([])
          expect(presenter.send(:build_elements_data)).to be_empty
        end
      end

      context "without diagram_objects" do
        before { allow(diagram).to receive(:diagram_objects).and_return(nil) }

        it { expect(presenter.send(:build_elements_data)).to eq([]) }
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
          double("DiagramLink", connector_xmi_id: "ASSOC_001",
                                geometry: "SX=0;SY=0;EX=0;EY=0;",
                                style: "SOID=OBJ1;EOID=OBJ2;", hidden: false)
        end

        let(:connectors) { presenter.send(:build_connectors_data) }

        before do
          allow(diagram).to receive_messages(diagram_objects: [],
                                             diagram_links: [diagram_link])
          allow(repository).to receive(:associations_index)
            .and_return([mock_association])
          allow(mock_association).to receive(:xmi_id).and_return("ASSOC_001")
        end

        it { expect(connectors).to be_an(Array) }
        it { expect(connectors.size).to eq(1) }
        it { expect(connectors.first[:element]).to eq(mock_association) }
        it { expect(connectors.first[:type]).to eq("association") }
        it { expect(connectors.first[:geometry]).to eq("SX=0;SY=0;EX=0;EY=0;") }
        it { expect(connectors.first[:diagram_link]).to eq(diagram_link) }

        it "filters hidden connectors" do
          allow(diagram_link).to receive(:hidden).and_return(true)
          expect(presenter.send(:build_connectors_data)).to be_empty
        end

        it "handles missing connector" do
          allow(repository).to receive(:associations_index).and_return([])
          expect(connectors.first[:type]).to eq("association")
        end
      end

      context "without diagram_links" do
        before { allow(diagram).to receive(:diagram_links).and_return(nil) }

        it { expect(presenter.send(:build_connectors_data)).to eq([]) }
      end
    end

    describe "#parse_diagram_link_style" do
      it "parses SOID" do
        r = presenter.send(:parse_diagram_link_style, "SOID=12345;EOID=67890;")
        expect(r[:soid]).to eq("12345")
      end

      it "parses EOID" do
        r = presenter.send(:parse_diagram_link_style, "SOID=12345;EOID=67890;")
        expect(r[:eoid]).to eq("67890")
      end

      it { expect(presenter.send(:parse_diagram_link_style, nil)).to eq({}) }
      it { expect(presenter.send(:parse_diagram_link_style, "")).to eq({}) }

      it "handles malformed style" do
        r = presenter.send(:parse_diagram_link_style, "INVALID;SOID=123;")
        expect(r[:soid]).to eq("123")
      end

      it "ignores unknown properties" do
        r = presenter.send(:parse_diagram_link_style, "UNKNOWN=999;SOID=123;")
        expect(r[:soid]).to eq("123")
      end
    end

    describe "#extract_ea_id" do
      let(:obj_with_duid) do
        double("DiagramObject", style: "NSL=0;DUID=ABC123;BCol=123;")
      end

      it {
        expect(presenter.send(:extract_ea_id, obj_with_duid)).to eq("ABC123")
      }

      it "returns nil for missing style" do
        obj = double("DiagramObject")
        allow(obj).to receive(:respond_to?).with(:style).and_return(false)
        expect(presenter.send(:extract_ea_id, obj)).to be_nil
      end

      it do
        expect(presenter.send(:extract_ea_id,
                              double("DiagramObject", style: nil))).to be_nil
      end

      it do
        expect(presenter.send(:extract_ea_id,
                              double("DiagramObject",
                                     style: "NSL=0;BCol=123;"))).to be_nil
      end
    end

    describe "#find_element_by_xmi_id" do
      let(:mock_cls) { double("Class", xmi_id: "CLASS_001") }
      let(:mock_pkg) { double("Package", xmi_id: "PKG_001") }

      before do
        allow(repository).to receive_messages(classes_index: [mock_cls],
                                              packages_index: [mock_pkg])
      end

      it {
        expect(presenter.send(:find_element_by_xmi_id,
                              "CLASS_001")).to eq(mock_cls)
      }

      it {
        expect(presenter.send(:find_element_by_xmi_id,
                              "PKG_001")).to eq(mock_pkg)
      }

      it {
        expect(presenter.send(:find_element_by_xmi_id, "NOT_FOUND")).to be_nil
      }

      it { expect(presenter.send(:find_element_by_xmi_id, nil)).to be_nil }

      it "returns nil when repository is nil" do
        pnr = described_class.new(diagram, nil)
        expect(pnr.send(:find_element_by_xmi_id, "CLASS_001")).to be_nil
      end
    end

    describe "#find_connector_by_xmi_id" do
      let(:mock_assoc) { double("Association", xmi_id: "ASSOC_001") }
      let(:mock_gen) { double("Generalization", xmi_id: "GEN_001") }
      let(:mock_class_gen) { double("Class", generalization: mock_gen) }

      before do
        allow(repository).to receive_messages(
          associations_index: [mock_assoc], classes_index: [mock_class_gen],
        )
        allow(mock_class_gen).to receive(:respond_to?)
          .with(:generalization).and_return(true)
        allow(mock_gen).to receive(:respond_to?)
          .with(:xmi_id).and_return(true)
      end

      it {
        expect(presenter.send(:find_connector_by_xmi_id,
                              "ASSOC_001")).to eq(mock_assoc)
      }

      it {
        expect(presenter.send(:find_connector_by_xmi_id,
                              "GEN_001")).to eq(mock_gen)
      }

      it "handles array of generalizations" do
        allow(mock_class_gen).to receive(:generalization).and_return([mock_gen])
        expect(presenter.send(:find_connector_by_xmi_id,
                              "GEN_001")).to eq(mock_gen)
      end

      context "with class associations" do
        let(:mca) { double("Association", xmi_id: "CLASS_ASSOC") }
        let(:mcwa) { double("Class", associations: [mca]) }

        before do
          allow(repository).to receive(:classes_index).and_return([mcwa])
          allow(mcwa).to receive(:respond_to?).with(:generalization).and_return(false)
          allow(mcwa).to receive(:generalization).and_return(nil)
          allow(mcwa).to receive(:respond_to?).with(:associations).and_return(true)
          allow(mca).to receive(:respond_to?).with(:xmi_id).and_return(true)
        end

        it {
          expect(presenter.send(:find_connector_by_xmi_id,
                                "CLASS_ASSOC")).to eq(mca)
        }
      end

      it "returns nil when not found" do
        allow(repository).to receive_messages(associations_index: [],
                                              classes_index: [])
        expect(presenter.send(:find_connector_by_xmi_id, "NOT_FOUND")).to be_nil
      end
    end

    describe "#find_connector_target" do
      let(:elements_map) { { "TARGET_ID" => { id: "TARGET_ID" } } }
      let(:target_result) do
        presenter.send(:find_connector_target, conn, elements_map)
      end

      context "with target property" do
        let(:conn) { double("Connector", target: "TARGET_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:target).and_return(true)
        end

        it { expect(target_result[:id]).to eq("TARGET_ID") }
      end

      context "with supplier property" do
        let(:conn) { double("Connector", supplier: "TARGET_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:target).and_return(false)
          allow(conn).to receive(:respond_to?).with(:supplier).and_return(true)
        end

        it { expect(target_result[:id]).to eq("TARGET_ID") }
      end

      context "with general property" do
        let(:conn) { double("Connector", general: "TARGET_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:target).and_return(false)
          allow(conn).to receive(:respond_to?).with(:supplier).and_return(false)
          allow(conn).to receive(:respond_to?).with(:general).and_return(true)
        end

        it { expect(target_result[:id]).to eq("TARGET_ID") }
      end

      context "with member_end" do
        let(:conn) { double("Connector", member_end: ["SRC", "TARGET_ID"]) }

        before do
          allow(conn).to receive(:respond_to?).with(:target).and_return(false)
          allow(conn).to receive(:respond_to?).with(:supplier).and_return(false)
          allow(conn).to receive(:respond_to?).with(:general).and_return(false)
          allow(conn).to receive(:respond_to?).with(:member_end).and_return(true)
        end

        it { expect(target_result[:id]).to eq("TARGET_ID") }
      end

      context "with no matching property" do
        let(:conn) { double("Connector") }

        before { allow(conn).to receive(:respond_to?).and_return(false) }

        it { expect(target_result).to be_nil }
      end
    end

    describe "#find_connector_source" do
      let(:elements_map) { { "SOURCE_ID" => { id: "SOURCE_ID" } } }
      let(:source_result) do
        presenter.send(:find_connector_source, conn, elements_map)
      end

      context "with source property" do
        let(:conn) { double("Connector", source: "SOURCE_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:source).and_return(true)
        end

        it { expect(source_result[:id]).to eq("SOURCE_ID") }
      end

      context "with client property" do
        let(:conn) { double("Connector", client: "SOURCE_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:source).and_return(false)
          allow(conn).to receive(:respond_to?).with(:client).and_return(true)
        end

        it { expect(source_result[:id]).to eq("SOURCE_ID") }
      end

      context "with specific property" do
        let(:conn) { double("Connector", specific: "SOURCE_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:source).and_return(false)
          allow(conn).to receive(:respond_to?).with(:client).and_return(false)
          allow(conn).to receive(:respond_to?).with(:specific).and_return(true)
        end

        it { expect(source_result[:id]).to eq("SOURCE_ID") }
      end

      context "with owner_end property" do
        let(:conn) { double("Connector", owner_end: "SOURCE_ID") }

        before do
          allow(conn).to receive(:respond_to?).with(:source).and_return(false)
          allow(conn).to receive(:respond_to?).with(:client).and_return(false)
          allow(conn).to receive(:respond_to?).with(:specific).and_return(false)
          allow(conn).to receive(:respond_to?).with(:owner_end).and_return(true)
        end

        it { expect(source_result[:id]).to eq("SOURCE_ID") }
      end

      context "with member_end" do
        let(:conn) { double("Connector", member_end: ["SOURCE_ID", "TGT"]) }

        before do
          allow(conn).to receive(:respond_to?).with(:source).and_return(false)
          allow(conn).to receive(:respond_to?).with(:client).and_return(false)
          allow(conn).to receive(:respond_to?).with(:specific).and_return(false)
          allow(conn).to receive(:respond_to?).with(:owner_end).and_return(false)
          allow(conn).to receive(:respond_to?).with(:member_end).and_return(true)
        end

        it { expect(source_result[:id]).to eq("SOURCE_ID") }
      end

      context "with no matching property" do
        let(:conn) { double("Connector") }

        before { allow(conn).to receive(:respond_to?).and_return(false) }

        it { expect(source_result).to be_nil }
      end
    end

    describe "#determine_element_type" do
      it "returns 'datatype' for DataType" do
        el = double("Element", class: double(name: "Lutaml::Uml::DataType"))
        expect(presenter.send(:determine_element_type, el)).to eq("datatype")
      end

      it "returns 'enum' for Enum" do
        el = double("Element", class: double(name: "Lutaml::Uml::Enum"))
        expect(presenter.send(:determine_element_type, el)).to eq("enum")
      end

      it "returns 'class' for Class" do
        el = double("Element", class: double(name: "Lutaml::Uml::Class"))
        expect(presenter.send(:determine_element_type, el)).to eq("class")
      end

      it "returns 'package' for Package" do
        el = double("Element", class: double(name: "Lutaml::Uml::Package"))
        expect(presenter.send(:determine_element_type, el)).to eq("package")
      end

      it "defaults to 'class' for unknown" do
        el = double("Element", class: double(name: "Unknown::Type"))
        expect(presenter.send(:determine_element_type, el)).to eq("class")
      end
    end

    describe "#determine_connector_type" do
      let(:gen_type) { double(name: "Lutaml::Uml::Generalization") }
      let(:assoc_type) { double(name: "Lutaml::Uml::Association") }
      let(:dep_type) { double(name: "Lutaml::Uml::Dependency") }
      let(:real_type) { double(name: "Lutaml::Uml::Realization") }
      let(:unknown_type) { double(name: "Unknown::Type") }

      it {
        expect(presenter.send(:determine_connector_type,
                              double(class: gen_type))).to eq("generalization")
      }

      it {
        expect(presenter.send(:determine_connector_type,
                              double(class: assoc_type))).to eq("association")
      }

      it {
        expect(presenter.send(:determine_connector_type,
                              double(class: dep_type))).to eq("dependency")
      }

      it {
        expect(presenter.send(:determine_connector_type,
                              double(class: real_type))).to eq("realization")
      }

      it {
        expect(presenter.send(:determine_connector_type,
                              double(class: unknown_type))).to eq("association")
      }
    end

    describe "#extract_stereotype" do
      it "extracts stereotype string" do
        el = double("Element", stereotype: "entity")
        allow(el).to receive(:respond_to?).with(:stereotype).and_return(true)
        expect(presenter.send(:extract_stereotype, el)).to eq("entity")
      end

      it "handles array of stereotypes" do
        el = double("Element", stereotype: ["entity", "feature"])
        allow(el).to receive(:respond_to?).with(:stereotype).and_return(true)
        expect(presenter.send(:extract_stereotype, el)).to eq("entity")
      end

      it "returns nil when not available" do
        el = double("Element")
        allow(el).to receive(:respond_to?).with(:stereotype).and_return(false)
        expect(presenter.send(:extract_stereotype, el)).to be_nil
      end

      it "returns nil for nil stereotype" do
        el = double("Element", stereotype: nil)
        allow(el).to receive(:respond_to?).with(:stereotype).and_return(true)
        expect(presenter.send(:extract_stereotype, el)).to be_nil
      end
    end

    describe "#extract_attributes" do
      let(:mock_attr) do
        double("Attribute", name: "id", type: "Integer", visibility: "public")
      end

      let(:element) do
        el = double("Element", attributes: [mock_attr])
        allow(el).to receive(:respond_to?).with(:attributes).and_return(true)
        allow(mock_attr).to receive(:respond_to?).with(:visibility).and_return(true)
        el
      end

      let(:attrs) { presenter.send(:extract_attributes, element) }

      it { expect(attrs).to be_an(Array) }
      it { expect(attrs.size).to eq(1) }
      it { expect(attrs.first[:name]).to eq("id") }
      it { expect(attrs.first[:type]).to eq("Integer") }
      it { expect(attrs.first[:visibility]).to eq("public") }

      it "returns empty array when not available" do
        el = double("Element")
        allow(el).to receive(:respond_to?).with(:attributes).and_return(false)
        expect(presenter.send(:extract_attributes, el)).to eq([])
      end

      it "returns empty array for nil attributes" do
        el = double("Element", attributes: nil)
        allow(el).to receive(:respond_to?).with(:attributes).and_return(true)
        expect(presenter.send(:extract_attributes, el)).to eq([])
      end
    end

    describe "#extract_operations" do
      let(:mock_param) { double("Parameter", name: "value", type: "String") }
      let(:mock_op) do
        double("Operation", name: "setValue", visibility: "public",
                            return_type: "void", owned_parameter: [mock_param])
      end

      let(:element) do
        el = double("Element", operations: [mock_op])
        allow(el).to receive(:respond_to?).with(:operations).and_return(true)
        allow(mock_op).to receive(:respond_to?).with(:visibility).and_return(true)
        allow(mock_op).to receive(:respond_to?).with(:return_type).and_return(true)
        allow(mock_op).to receive(:respond_to?).with(:owned_parameter).and_return(true)
        el
      end

      let(:ops) { presenter.send(:extract_operations, element) }

      it { expect(ops).to be_an(Array) }
      it { expect(ops.size).to eq(1) }
      it { expect(ops.first[:name]).to eq("setValue") }
      it { expect(ops.first[:visibility]).to eq("public") }
      it { expect(ops.first[:return_type]).to eq("void") }
      it { expect(ops.first[:parameters]).to be_an(Array) }

      it "returns empty array when not available" do
        el = double("Element")
        allow(el).to receive(:respond_to?).with(:operations).and_return(false)
        expect(presenter.send(:extract_operations, el)).to eq([])
      end
    end

    describe "#extract_parameters" do
      let(:mock_param) { double("Parameter", name: "value", type: "String") }
      let(:operation) do
        op = double("Operation", owned_parameter: [mock_param])
        allow(op).to receive(:respond_to?).with(:owned_parameter).and_return(true)
        op
      end

      let(:params) { presenter.send(:extract_parameters, operation) }

      it { expect(params).to be_an(Array) }
      it { expect(params.size).to eq(1) }
      it { expect(params.first[:name]).to eq("value") }
      it { expect(params.first[:type]).to eq("String") }

      it "returns empty array when not available" do
        op = double("Operation")
        allow(op).to receive(:respond_to?).with(:owned_parameter).and_return(false)
        expect(presenter.send(:extract_parameters, op)).to eq([])
      end

      it "returns empty array for nil parameters" do
        op = double("Operation", owned_parameter: nil)
        allow(op).to receive(:respond_to?).with(:owned_parameter).and_return(true)
        expect(presenter.send(:extract_parameters, op)).to eq([])
      end
    end
  end

  describe "DiagramRendererWrapper" do
    let(:layout_engine) { Lutaml::Ea::Diagram::LayoutEngine.new }
    let(:diagram_data) do
      { name: "Test",
        elements: [{ id: "1", x: 0, y: 0, width: 100, height: 80 }],
        connectors: [{ id: "c1", type: "association" }] }
    end
    let(:wrapper) do
      described_class::DiagramRendererWrapper.new(diagram_data, layout_engine)
    end

    describe "#initialize" do
      it { expect(wrapper.diagram_data).to eq(diagram_data) }
      it { expect(wrapper.elements).to eq(diagram_data[:elements]) }
      it { expect(wrapper.connectors).to eq(diagram_data[:connectors]) }
      it { expect(wrapper.bounds).to be_a(Hash) }
      it { expect(wrapper.bounds).to have_key(:x) }
      it { expect(wrapper.bounds).to have_key(:y) }
      it { expect(wrapper.bounds).to have_key(:width) }
      it { expect(wrapper.bounds).to have_key(:height) }

      it "handles empty elements" do
        d = { name: "Empty", elements: [], connectors: [] }
        w = described_class::DiagramRendererWrapper.new(d, layout_engine)
        expect(w.elements).to eq([])
      end

      it "handles nil elements" do
        d = { name: "Nil", elements: nil, connectors: nil }
        w = described_class::DiagramRendererWrapper.new(d, layout_engine)
        expect(w.elements).to eq([])
      end
    end

    describe "accessors" do
      it { expect(wrapper).to respond_to(:diagram_data) }
      it { expect(wrapper).to respond_to(:bounds) }
      it { expect(wrapper).to respond_to(:elements) }
      it { expect(wrapper).to respond_to(:connectors) }
    end
  end
end
