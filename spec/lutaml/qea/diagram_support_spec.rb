# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/services/database_loader"
require_relative "../../../lib/lutaml/qea/factory/diagram_transformer"

RSpec.describe "Comprehensive Diagram Support" do
  let(:qea_path) { "examples/qea/20251010_current_plateau_v5.1.qea" }
  let(:loader) { Lutaml::Qea::Services::DatabaseLoader.new(qea_path) }
  let(:database) { loader.load }

  describe "Phase 1: Database Loading" do
    it "loads diagram objects table successfully", :aggregate_failures do
      expect(database.diagram_objects).to be_an(Array)
      expect(database.diagram_objects.size).to eq(1767)
    end

    it "loads diagram links table successfully", :aggregate_failures do
      expect(database.diagram_links).to be_an(Array)
      expect(database.diagram_links.size).to eq(1813)
    end

    it "loads diagram objects with correct attributes", :aggregate_failures do
      obj = database.diagram_objects.first
      expect(obj).to be_a(Lutaml::Qea::Models::EaDiagramObject)
      expect(obj.diagram_id).to be_a(Integer)
      expect(obj.object_id).to be_a(Integer)
      expect(obj.instance_id).to be_a(Integer)
    end

    it "loads diagram links with correct attributes", :aggregate_failures do
      link = database.diagram_links.first
      expect(link).to be_a(Lutaml::Qea::Models::EaDiagramLink)
      expect(link.diagramid).to be_a(Integer)
      expect(link.connectorid).to be_a(Integer)
      expect(link.instance_id).to be_a(Integer)
    end
  end

  describe "Phase 2: Model Functionality" do
    describe "EaDiagramObject" do
      let(:diagram_object) { database.diagram_objects.first }

      it "calculates bounding box correctly", :aggregate_failures do
        bbox = diagram_object.bounding_box
        expect(bbox).to have_key(:top)
        expect(bbox).to have_key(:left)
        expect(bbox).to have_key(:right)
        expect(bbox).to have_key(:bottom)
        expect(bbox).to have_key(:width)
        expect(bbox).to have_key(:height)

        expect(bbox[:width]).to eq(bbox[:right] - bbox[:left])
        expect(bbox[:height]).to eq(bbox[:bottom] - bbox[:top])
      end

      it "calculates center point correctly", :aggregate_failures do
        center = diagram_object.center_point
        expect(center).to have_key(:x)
        expect(center).to have_key(:y)

        bbox = diagram_object.bounding_box
        expect(center[:x]).to eq((bbox[:left] + bbox[:right]) / 2)
        expect(center[:y]).to eq((bbox[:top] + bbox[:bottom]) / 2)
      end

      it "parses style string into hash", :aggregate_failures do
        style = diagram_object.parsed_style
        expect(style).to be_a(Hash)
        # ObjectStyle format: "DUID=98A7EF40;"
        expect(style).to have_key("DUID") if diagram_object.objectstyle
      end
    end

    describe "EaDiagramLink" do
      let(:diagram_link) { database.diagram_links.first }

      it "detects hidden status" do
        expect([true, false]).to include(diagram_link.hidden?)
      end

      it "parses style string into hash" do
        style = diagram_link.parsed_style
        expect(style).to be_a(Hash)
      end

      it "parses geometry data" do
        geometry = diagram_link.parsed_geometry
        expect(geometry).to be_a(Hash)
      end

      it "extracts object IDs from style", :aggregate_failures do
        ids = diagram_link.object_ids
        expect(ids).to have_key(:source_oid)
        expect(ids).to have_key(:dest_oid)
      end
    end
  end

  describe "Phase 3: UML Diagram Transformation" do
    let(:transformer) do
      Lutaml::Qea::Factory::DiagramTransformer.new(database)
    end
    let(:ea_diagram) { database.diagrams.first }
    let(:uml_diagram) { transformer.transform(ea_diagram) }

    it "transforms EA diagram to UML diagram", :aggregate_failures do
      expect(uml_diagram).to be_a(Lutaml::Uml::Diagram)
      expect(uml_diagram.name).to eq(ea_diagram.name)
      expect(uml_diagram.xmi_id)
        .to eq("EAID_#{ea_diagram.ea_guid.tr('{}', '').tr('-', '_')}")
    end

    it "includes diagram type in transformation" do
      expect(uml_diagram.diagram_type).to eq(ea_diagram.diagram_type)
    end

    it "loads diagram objects for the diagram", :aggregate_failures do
      expect(uml_diagram.diagram_objects).to be_an(Array)
      expect(uml_diagram.diagram_objects).not_to be_empty

      obj = uml_diagram.diagram_objects.first
      expect(obj).to be_a(Lutaml::Uml::DiagramObject)
    end

    it "loads diagram links for the diagram", :aggregate_failures do
      expect(uml_diagram.diagram_links).to be_an(Array)
      expect(uml_diagram.diagram_links).not_to be_empty

      link = uml_diagram.diagram_links.first
      expect(link).to be_a(Lutaml::Uml::DiagramLink)
    end

    it "preserves diagram object properties", :aggregate_failures do
      obj = uml_diagram.diagram_objects.first
      expect(obj.object_id).to be_a(Integer)
      expect(obj.left).to be_a(Integer)
      expect(obj.top).to be_a(Integer)
      expect(obj.right).to be_a(Integer)
      expect(obj.bottom).to be_a(Integer)
    end

    it "preserves diagram link properties", :aggregate_failures do
      link = uml_diagram.diagram_links.first
      expect(link.connector_id).to be_a(String)
      expect([true, false]).to include(link.hidden)
    end

    it "links diagram objects to UML elements via xmi_id" do
      obj = uml_diagram.diagram_objects.first
      # Should have either object_id or object_xmi_id
      expect(obj.object_id).not_to be_nil
    end

    it "links diagram links to connectors via xmi_id" do
      link = uml_diagram.diagram_links.first
      # Should have either connector_id or connector_xmi_id
      expect(link.connector_id).not_to be_nil
    end
  end

  describe "Phase 4: Integration with Full Pipeline" do
    it "includes diagrams in database statistics", :aggregate_failures do
      stats = database.stats
      expect(stats).to have_key("diagram_objects")
      expect(stats).to have_key("diagram_links")
      expect(stats["diagram_objects"]).to eq(1767)
      expect(stats["diagram_links"]).to eq(1813)
    end

    it "maintains referential integrity" do
      # Check that diagram objects reference valid diagrams and objects
      aggregate_failures do
        diagram_object = database.diagram_objects.first
        diagram = database.find_diagram(diagram_object.diagram_id)
        expect(diagram).to be_a(Lutaml::Qea::Models::EaDiagram)

        object = database.find_object(diagram_object.ea_object_id)
        expect(object).to be_a(Lutaml::Qea::Models::EaObject)
      end
    end

    it "maintains connector references in diagram links" do
      # Check that diagram links reference valid connectors
      diagram_link = database.diagram_links.first
      connector = database.find_connector(diagram_link.connectorid)
      expect(connector).to be_a(Lutaml::Qea::Models::EaConnector)
    end
  end

  describe "Phase 5: Performance and Data Integrity" do
    it "loads all diagram data efficiently", :aggregate_failures do
      start_time = Time.now
      database = loader.load
      load_time = Time.now - start_time

      # Should load within reasonable time (generous threshold for CI runners)
      expect(load_time).to be < 120.0
      expect(database.diagram_objects.size).to eq(1767)
      expect(database.diagram_links.size).to eq(1813)
    end

    it "freezes collections after loading", :aggregate_failures do
      database = loader.load
      expect(database.diagram_objects).to be_frozen
      expect(database.diagram_links).to be_frozen
    end

    it "handles diagrams with many objects" do
      # Find a diagram with the most objects
      diagram_objects_by_diagram = database.diagram_objects
        .group_by(&:diagram_id)

      largest_diagram_id = diagram_objects_by_diagram
        .max_by { |_id, objs| objs.size }
        &.first

      if largest_diagram_id
        diagram = database.find_diagram(largest_diagram_id)
        transformer = Lutaml::Qea::Factory::DiagramTransformer.new(database)
        uml_diagram = transformer.transform(diagram)

        expect(uml_diagram.diagram_objects.size).to be > 0
      end
    end
  end
end
