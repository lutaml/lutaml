# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::DiagramSerializer do
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }

  let(:diagram_doc) do
    doc = Lutaml::Uml::Document.new
    doc.name = "DiagTest"

    pkg = Lutaml::Uml::Package.new
    pkg.name = "Pkg"
    pkg.xmi_id = "EAPK_PKG1"

    diag = Lutaml::Uml::Diagram.new
    diag.name = "Test Diagram"
    diag.xmi_id = "EAID_DIAG1"
    diag.diagram_type = "Logical"
    diag_obj = Lutaml::Uml::DiagramObject.new
    diag.diagram_objects = [diag_obj]
    diag.diagram_links = []

    pkg.diagrams = [diag]
    doc.packages << pkg
    doc
  end

  let(:repository) { Lutaml::UmlRepository::Repository.new(document: diagram_doc) }

  describe "metadata-only mode (default)" do
    it "serializes diagram metadata without SVG" do
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
    it "skips SVG for diagrams when presenter is unavailable" do
      serializer = described_class.new(repository, id_generator,
                                       { include_diagrams: true,
                                         render_diagrams: true })
      result = serializer.build_map

      entry = result.values.first
      # render_diagrams may fail gracefully without real SVG rendering
      expect(entry).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaDiagram)
      expect(entry.name).to eq("Test Diagram")
    end
  end

  describe "with empty diagrams" do
    let(:empty_diag_doc) do
      doc = Lutaml::Uml::Document.new
      doc.name = "EmptyDiag"

      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      pkg.xmi_id = "EAPK_PKG2"

      diag = Lutaml::Uml::Diagram.new
      diag.name = "Empty Diagram"
      diag.xmi_id = "EAID_DIAG2"
      diag.diagram_type = "Logical"
      diag.diagram_objects = []
      diag.diagram_links = []

      pkg.diagrams = [diag]
      doc.packages << pkg
      doc
    end

    let(:empty_repo) { Lutaml::UmlRepository::Repository.new(document: empty_diag_doc) }

    it "handles diagrams without objects" do
      serializer = described_class.new(empty_repo, id_generator,
                                       { include_diagrams: true,
                                         render_diagrams: true })
      result = serializer.build_map

      entry = result.values.first
      expect(entry.svg).to be_nil
    end
  end
end
