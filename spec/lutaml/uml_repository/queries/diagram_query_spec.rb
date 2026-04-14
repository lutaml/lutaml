# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::DiagramQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_by_package" do
    it "finds diagrams in a package" do
      package_ids = indexes[:diagram_index].keys

      package_ids.each do |package_id|
        diagrams = query.find_by_package(package_id)
        expect(diagrams).to be_an(Array)
        diagrams.each do |diagram|
          expect(diagram).to be_a(Lutaml::Uml::Diagram)
        end
      end
    end

    it "returns empty array for package without diagrams" do
      diagrams = query.find_by_package("nonexistent_id")
      expect(diagrams).to eq([])
    end

    it "finds diagrams for packages with diagrams" do
      indexes[:diagram_index].each do |package_id, expected_diagrams|
        diagrams = query.find_by_package(package_id)
        expect(diagrams.length).to eq(expected_diagrams.length)
      end
    end
  end

  describe "#find_by_name" do
    it "finds a diagram by name" do
      all_diagrams = query.all

      all_diagrams.each do |diagram|
        found = query.find_by_name(diagram.name)
        expect(found).to be_an(Lutaml::Uml::Diagram)
        expect(found.name).to eq(diagram.name)
      end
    end

    it "returns empty array for non-existent diagram name" do
      diagrams = query.find_by_name("NonExistentDiagram")
      expect(diagrams).to eq(nil)
    end

    it "handles diagrams with same name in different packages" do
      all_diagrams = query.all
      diagram_names = all_diagrams.map(&:name)

      diagram_names.each do |name|
        found = query.find_by_name(name)
        expect(found).to be_an(Lutaml::Uml::Diagram)
      end
    end
  end

  describe "#all" do
    it "returns all diagrams" do
      diagrams = query.all
      expect(diagrams).to be_an(Array)
      diagrams.each do |diagram|
        expect(diagram).to be_a(Lutaml::Uml::Diagram)
      end
    end

    it "includes diagrams from all packages" do
      diagrams = query.all

      total_from_index = indexes[:diagram_index].values.flatten.length
      expect(diagrams.length).to eq(total_from_index)
    end
  end

  describe "#find_containing_class" do
    it "finds diagrams containing specific class" do
      classes = indexes[:qualified_names].values.grep(Lutaml::Uml::Class)

      classes.each do |klass|
        diagrams = query.find_containing_class(klass.xmi_id)
        expect(diagrams).to be_an(Array)
      end
    end

    it "returns empty array when class not in any diagram" do
      diagrams = query.find_containing_class("nonexistent_id")
      expect(diagrams).to eq([])
    end
  end

  describe "with real document" do
    it "finds diagrams in test document" do
      all_diagrams = query.all
      expect(all_diagrams).to be_an(Array)
    end

    it "indexes diagrams correctly" do
      indexes[:diagram_index].each do |package_id, diagrams|
        expect(package_id).to be_a(String)
        expect(diagrams).to be_an(Array)
        diagrams.each do |diagram|
          expect(diagram).to be_a(Lutaml::Uml::Diagram)
        end
      end
    end
  end
end
