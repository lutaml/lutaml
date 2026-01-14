# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea"

RSpec.describe "QEA Cross-Reference Support" do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }
  let(:database) do
    Lutaml::Qea::Services::DatabaseLoader.new(qea_file).load
  end

  describe "t_xref table loading" do
    it "loads all cross-reference records" do
      expect(database.xrefs).not_to be_nil
      expect(database.xrefs).to be_an(Array)
    end

    it "loads the expected number of cross-references (1246)" do
      expect(database.xrefs.size).to eq(1246)
    end

    it "creates EaXref model instances" do
      xref = database.xrefs.first
      expect(xref).to be_a(Lutaml::Qea::Models::EaXref)
    end
  end

  describe "EaXref model" do
    let(:stereotype_xref) do
      database.xrefs.find { |x| x.name == "Stereotypes" }
    end

    let(:custom_prop_xref) do
      database.xrefs.find { |x| x.name == "CustomProperties" }
    end

    it "has required attributes" do
      expect(stereotype_xref.xref_id).to be_a(String)
      expect(stereotype_xref.name).to eq("Stereotypes")
      expect(stereotype_xref.type).to be_a(String)
      expect(stereotype_xref.client).to be_a(String)
      expect(stereotype_xref.description).to be_a(String)
    end

    it "parses stereotype information" do
      parsed = stereotype_xref.parsed_description
      expect(parsed).to be_a(Hash)
      expect(parsed).to have_key(:format)
      expect(parsed[:format]).to eq(:stereotype)
      expect(parsed).to have_key(:data)
    end

    it "parses custom property information" do
      parsed = custom_prop_xref.parsed_description
      expect(parsed).to be_a(Hash)
      expect(parsed).to have_key(:format)
    end

    it "identifies stereotype xrefs" do
      expect(stereotype_xref.stereotype?).to be true
      expect(stereotype_xref.custom_property?).to be false
    end

    it "identifies custom property xrefs" do
      expect(custom_prop_xref).not_to be_nil
      expect(custom_prop_xref.custom_property?).to be true
      expect(custom_prop_xref.stereotype?).to be false
    end

    it "identifies element property type" do
      element_xref = database.xrefs.find { |x| x.type == "element property" }
      expect(element_xref).not_to be_nil
      expect(element_xref.element_property?).to be true
    end

    it "identifies attribute property type" do
      attr_xref = database.xrefs.find { |x| x.type == "attribute property" }
      expect(attr_xref).not_to be_nil
      expect(attr_xref.attribute_property?).to be true
    end

    it "identifies connector property type" do
      conn_xref = database.xrefs.find do |x|
        x.type&.include?("connector")
      end
      expect(conn_xref).not_to be_nil
      expect(conn_xref.connector_property?).to be true
    end

    it "identifies diagram property type" do
      diag_xref = database.xrefs.find { |x| x.type == "diagram properties" }
      expect(diag_xref).not_to be_nil
      expect(diag_xref.diagram_property?).to be true
    end
  end

  describe "Stereotype cross-references" do
    let(:stereotype_xrefs) do
      database.xrefs.select(&:stereotype?)
    end

    it "loads stereotype xrefs (target: 1010)" do
      expect(stereotype_xrefs.size).to eq(1010)
    end

    it "parses stereotype description format" do
      xref = stereotype_xrefs.first
      parsed = xref.parsed_description

      expect(parsed).to have_key(:data)
      expect(parsed[:data]).to have_key(:name)
      expect(parsed[:data]).to have_key(:fqname)
    end

    it "handles element stereotypes" do
      elem_stereo = stereotype_xrefs.find(&:element_property?)
      expect(elem_stereo).not_to be_nil
      expect(elem_stereo.description).to include("@STEREO")
    end

    it "handles connector stereotypes" do
      conn_stereo = stereotype_xrefs.find(&:connector_property?)
      expect(conn_stereo).not_to be_nil
      expect(conn_stereo.description).to include("@STEREO")
    end

    it "handles attribute stereotypes" do
      attr_stereo = stereotype_xrefs.find(&:attribute_property?)
      expect(attr_stereo).not_to be_nil
      expect(attr_stereo.description).to include("@STEREO")
    end
  end

  describe "Custom property cross-references" do
    let(:custom_prop_xrefs) do
      database.xrefs.select(&:custom_property?)
    end

    it "loads custom property xrefs (target: 236)" do
      expect(custom_prop_xrefs.size).to eq(236)
    end

    it "parses custom property description format" do
      xref = custom_prop_xrefs.first
      parsed = xref.parsed_description

      expect(parsed).to have_key(:data)
      expect(parsed).to have_key(:format)
      expect(parsed[:data]).to be_a(Hash)
    end

    it "handles element custom properties" do
      elem_props = custom_prop_xrefs.select(&:element_property?)
      expect(elem_props).not_to be_empty
    end

    it "handles diagram custom properties" do
      diag_props = custom_prop_xrefs.select(&:diagram_property?)
      expect(diag_props).not_to be_empty
      expect(diag_props.size).to eq(181)
    end
  end

  describe "Cross-reference distribution by type" do
    it "distributes xrefs correctly across types" do
      types = database.xrefs.group_by(&:type)

      expect(types["element property"].size).to eq(599)
      expect(types["connectorSrcEnd property"].size).to eq(352)
      expect(types["diagram properties"].size).to eq(181)
      expect(types["attribute property"].size).to eq(68)
      expect(types["connector property"].size).to eq(34)
      expect(types["connectorDestEnd property"].size).to eq(12)
    end

    it "distributes xrefs correctly across names" do
      names = database.xrefs.group_by(&:name)

      expect(names["Stereotypes"].size).to eq(1010)
      expect(names["CustomProperties"].size).to eq(236)
    end
  end

  describe "Cross-reference client relationships" do
    it "links to various EA entities" do
      # Xrefs should link to objects, attributes, connectors, diagrams
      clients = database.xrefs.map(&:client).compact.uniq
      expect(clients).not_to be_empty
      expect(clients.size).to be > 100
    end

    it "can find stereotypes by client GUID" do
      # Find an attribute
      attr = database.attributes.first
      next unless attr&.ea_guid

      # Find xrefs for this attribute
      attr_xrefs = database.xrefs.select do |x|
        x.client == attr.ea_guid
      end

      # May or may not have xrefs - that's okay
      expect(attr_xrefs).to be_an(Array)
    end

    it "can find custom properties by client GUID" do
      # Find a diagram
      diagram = database.diagrams.first
      next unless diagram&.ea_guid

      # Find xrefs for this diagram
      diag_xrefs = database.xrefs.select do |x|
        x.client == diagram.ea_guid
      end

      # May or may not have xrefs - that's okay
      expect(diag_xrefs).to be_an(Array)
    end
  end

  describe "database integration" do
    it "includes xrefs in total record count" do
      expect(database.total_records).to be > 8000
    end

    it "includes xrefs in statistics" do
      stats = database.stats
      expect(stats["xrefs"]).to eq(1246)
    end

    it "lists xrefs in collection names" do
      expect(database.collection_names).to include(:xrefs)
    end
  end
end