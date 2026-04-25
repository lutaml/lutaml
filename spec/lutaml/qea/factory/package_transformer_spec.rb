# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/package_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_package"

RSpec.describe Lutaml::Qea::Factory::PackageTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA package to UML package", :aggregate_failures do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Domain",
        ea_guid: "{PKG-GUID}",
        notes: "Domain model package",
      )

      allow(database).to receive(:xrefs).and_return(nil)
      result = transformer.transform(ea_pkg)

      expect(result).to be_a(Lutaml::Uml::Package)
      expect(result.name).to eq("Domain")
      expect(result.xmi_id).to eq("EAPK_PKG_GUID")
      expect(result.definition).to eq("Domain model package")
      expect(result.packages).to eq([])
      expect(result.classes).to eq([])
    end

    it "skips empty notes" do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Package",
        notes: "",
      )

      result = transformer.transform(ea_pkg)

      expect(result.definition).to be_nil
    end
  end

  describe "#transform_with_hierarchy" do
    it "loads child packages", :aggregate_failures do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Root",
      )

      child_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 2,
        name: "Child",
        parent_id: 1,
        ea_guid: "{CHILD-GUID}",
      )

      allow(database).to receive(:child_packages_for).with(1).and_return([child_pkg])
      allow(database).to receive(:child_packages_for).with(2).and_return([])
      allow(database).to receive_messages(objects_in_package: [],
                                          diagrams_in_package: [], xrefs: nil)

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.packages.size).to eq(1)
      expect(result.packages.first.name).to eq("Child")
    end

    it "loads package objects as classes", :aggregate_failures do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Models",
      )

      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 10,
        object_type: "Class",
        name: "Entity",
        package_id: 1,
      )

      allow(database).to receive(:child_packages_for).with(1).and_return([])
      allow(database).to receive(:objects_in_package).with(1).and_return([ea_obj])
      allow(database).to receive(:attributes_for_object).with(10).and_return([])
      allow(database).to receive(:operations_for_object).with(10).and_return([])
      allow(database).to receive(:connectors_for_object).with(10).and_return([])
      allow(database).to receive(:diagrams_in_package).with(1).and_return([])
      allow(database).to receive(:find_object).with(10).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, object_constraints: [],
                                          object_properties: [], attribute_tags: [], tagged_values: [], find_package: nil)

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.classes.size).to eq(1)
      expect(result.classes.first.name).to eq("Entity")
    end

    it "loads package diagrams", :aggregate_failures do
      ea_pkg = Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "Views",
      )

      ea_diagram = Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 5,
        package_id: 1,
        name: "Class Diagram",
      )

      allow(database).to receive(:child_packages_for).with(1).and_return([])
      allow(database).to receive(:objects_in_package).with(1).and_return([])
      allow(database).to receive(:diagrams_in_package).with(1).and_return([ea_diagram])
      allow(database).to receive(:find_package).with(1).and_return(nil)
      allow(database).to receive(:diagram_objects_for).with(5).and_return([])
      allow(database).to receive(:diagram_links_for).with(5).and_return([])

      result = transformer.transform_with_hierarchy(ea_pkg)

      expect(result.diagrams.size).to eq(1)
      expect(result.diagrams.first.name).to eq("Class Diagram")
    end
  end
end
