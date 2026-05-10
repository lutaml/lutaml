# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../../lib/lutaml/uml_repository/static_site/serializers/diagram_serializer"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::DiagramSerializer do
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IDGenerator.new }

  describe "metadata-only mode (default)" do
    it "serializes diagram metadata without SVG" do
      repository = instance_double(Lutaml::UmlRepository::Repository)
      diagram = instance_double(Lutaml::Uml::Diagram,
                                xmi_id: "EAID_ABC123",
                                name: "Test Diagram",
                                diagram_type: "Logical",
                                diagram_objects: [double("obj")],
                                diagram_links: [])
      pkg = instance_double(Lutaml::Uml::Package,
                            xmi_id: "EAPK_PKG1",
                            diagrams: [diagram])

      allow(repository).to receive_messages(diagrams_index: [diagram],
                                            packages_index: [pkg])

      serializer = described_class.new(repository, id_generator,
                                       { include_diagrams: true })
      result = serializer.build_map

      expect(result.size).to eq(1)
      entry = result.values.first
      expect(entry).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDiagram)
      expect(entry.name).to eq("Test Diagram")
      expect(entry.type).to eq("Logical")
      expect(entry.object_count).to eq(1)
      expect(entry.link_count).to eq(0)
      expect(entry.svg).to be_nil
    end
  end

  describe "with render_diagrams option" do
    it "includes SVG when diagram has objects" do
      repository = instance_double(Lutaml::UmlRepository::Repository)
      diagram = instance_double(Lutaml::Uml::Diagram,
                                xmi_id: "EAID_ABC123",
                                name: "Test Diagram",
                                diagram_type: "Logical",
                                diagram_objects: [double("obj")],
                                diagram_links: [])
      pkg = instance_double(Lutaml::Uml::Package,
                            xmi_id: "EAPK_PKG1",
                            diagrams: [diagram])

      allow(repository).to receive_messages(diagrams_index: [diagram],
                                            packages_index: [pkg])

      svg_content = '<svg xmlns="http://www.w3.org/2000/svg"><rect/></svg>'
      presenter = instance_double(Lutaml::UmlRepository::Presenters::DiagramPresenter)
      allow(presenter).to receive(:svg_output).and_return(svg_content)
      allow(Lutaml::UmlRepository::Presenters::DiagramPresenter).to receive(:new)
        .with(diagram, repository).and_return(presenter)

      serializer = described_class.new(repository, id_generator,
                                       { include_diagrams: true,
                                         render_diagrams: true })
      result = serializer.build_map

      entry = result.values.first
      expect(entry.svg).to eq(svg_content)
    end

    it "skips SVG for diagrams without objects" do
      repository = instance_double(Lutaml::UmlRepository::Repository)
      diagram = instance_double(Lutaml::Uml::Diagram,
                                xmi_id: "EAID_ABC123",
                                name: "Empty Diagram",
                                diagram_type: "Logical",
                                diagram_objects: [],
                                diagram_links: [])
      pkg = instance_double(Lutaml::Uml::Package,
                            xmi_id: "EAPK_PKG1",
                            diagrams: [diagram])

      allow(repository).to receive_messages(diagrams_index: [diagram],
                                            packages_index: [pkg])

      serializer = described_class.new(repository, id_generator,
                                       { include_diagrams: true,
                                         render_diagrams: true })
      result = serializer.build_map

      entry = result.values.first
      expect(entry.svg).to be_nil
    end
  end
end
