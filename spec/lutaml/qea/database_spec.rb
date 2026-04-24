# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/database"
require_relative "../../../lib/lutaml/qea/models/ea_object"
require_relative "../../../lib/lutaml/qea/models/ea_package"
require_relative "../../../lib/lutaml/qea/models/ea_attribute"
require_relative "../../../lib/lutaml/qea/models/ea_operation"
require_relative "../../../lib/lutaml/qea/models/ea_operation_param"
require_relative "../../../lib/lutaml/qea/models/ea_connector"
require_relative "../../../lib/lutaml/qea/models/ea_diagram"
require_relative "../../../lib/lutaml/qea/models/ea_diagram_object"
require_relative "../../../lib/lutaml/qea/models/ea_diagram_link"

RSpec.describe Lutaml::Qea::Database do
  let(:qea_path) { "test.qea" }
  let(:database) { described_class.new(qea_path) }

  let(:sample_object) do
    Lutaml::Qea::Models::EaObject.new(
      ea_object_id: 1,
      name: "TestClass",
      object_type: "Class",
      package_id: 10,
    )
  end

  let(:sample_package) do
    Lutaml::Qea::Models::EaPackage.new(
      package_id: 10,
      name: "TestPackage",
      parent_id: 0,
    )
  end

  let(:sample_attribute) do
    Lutaml::Qea::Models::EaAttribute.new(
      id: 100,
      ea_object_id: 1,
      name: "testAttr",
      type: "String",
    )
  end

  describe "#initialize" do
    it "creates a new database instance" do
      expect(database).to be_a(described_class)
    end

    it "stores the QEA path" do
      expect(database.qea_path).to eq(qea_path)
    end

    it "initializes with empty collections" do
      expect(database.collections).to eq({})
    end
  end

  describe "#add_collection" do
    it "adds a collection with symbol key" do
      database.add_collection(:objects, [sample_object])
      expect(database.collections[:objects]).to eq([sample_object])
    end

    it "adds a collection with string key" do
      database.add_collection("objects", [sample_object])
      expect(database.collections[:objects]).to eq([sample_object])
    end

    it "freezes the collection" do
      database.add_collection(:objects, [sample_object])
      expect(database.collections[:objects]).to be_frozen
    end

    it "is thread-safe" do
      threads = Array.new(10) do |i|
        Thread.new do
          database.add_collection("collection_#{i}", [sample_object])
        end
      end
      threads.each(&:join)

      expect(database.collections.size).to eq(10)
    end
  end

  describe "#objects" do
    it "returns an ObjectRepository" do
      database.add_collection(:objects, [sample_object])
      expect(database.objects).to be_a(Lutaml::Qea::Repositories::ObjectRepository)
    end

    it "returns empty repository when no objects" do
      repo = database.objects
      expect(repo.all).to eq([])
    end

    it "contains added objects" do
      database.add_collection(:objects, [sample_object])
      expect(database.objects.all).to eq([sample_object])
    end
  end

  describe "#attributes" do
    it "returns attributes collection" do
      database.add_collection(:attributes, [sample_attribute])
      expect(database.attributes).to eq([sample_attribute])
    end

    it "returns empty array when no attributes" do
      expect(database.attributes).to eq([])
    end
  end

  describe "#packages" do
    it "returns packages collection" do
      database.add_collection(:packages, [sample_package])
      expect(database.packages).to eq([sample_package])
    end
  end

  describe "#stats" do
    it "returns empty stats for empty database" do
      expect(database.stats).to eq({})
    end

    it "returns counts for each collection" do
      database.add_collection(:objects, [sample_object, sample_object])
      database.add_collection(:packages, [sample_package])
      database.add_collection(:attributes,
                              [sample_attribute, sample_attribute,
                               sample_attribute])

      stats = database.stats
      expect(stats).to eq({
                            "objects" => 2,
                            "packages" => 1,
                            "attributes" => 3,
                          })
    end
  end

  describe "#total_records" do
    it "returns 0 for empty database" do
      expect(database.total_records).to eq(0)
    end

    it "returns sum of all records" do
      database.add_collection(:objects, [sample_object, sample_object])
      database.add_collection(:packages, [sample_package])

      expect(database.total_records).to eq(3)
    end
  end

  describe "#find_object" do
    before do
      database.add_collection(:objects, [sample_object])
    end

    it "finds object by ID" do
      result = database.find_object(1)
      expect(result).to eq(sample_object)
    end

    it "returns nil for non-existent ID" do
      result = database.find_object(999)
      expect(result).to be_nil
    end
  end

  describe "#find_package" do
    before do
      database.add_collection(:packages, [sample_package])
    end

    it "finds package by ID" do
      result = database.find_package(10)
      expect(result).to eq(sample_package)
    end

    it "returns nil for non-existent ID" do
      result = database.find_package(999)
      expect(result).to be_nil
    end
  end

  describe "#find_attribute" do
    before do
      database.add_collection(:attributes, [sample_attribute])
    end

    it "finds attribute by ID" do
      result = database.find_attribute(100)
      expect(result).to eq(sample_attribute)
    end

    it "returns nil for non-existent ID" do
      result = database.find_attribute(999)
      expect(result).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true for new database" do
      expect(database.empty?).to be true
    end

    it "returns false when collections exist" do
      database.add_collection(:objects, [sample_object])
      expect(database.empty?).to be false
    end

    it "returns true when collections are empty" do
      database.add_collection(:objects, [])
      expect(database.empty?).to be true
    end
  end

  describe "#collection_names" do
    it "returns empty array for new database" do
      expect(database.collection_names).to eq([])
    end

    it "returns all collection names" do
      database.add_collection(:objects, [sample_object])
      database.add_collection(:packages, [sample_package])

      expect(database.collection_names).to contain_exactly(:objects, :packages)
    end
  end

  describe "#find_object_by_guid" do
    let(:obj_with_guid) do
      Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 5,
        name: "GuidObject",
        ea_guid: "{ABC-123}",
      )
    end

    before do
      database.add_collection(:objects, [obj_with_guid])
    end

    it "finds object by ea_guid" do
      expect(database.find_object_by_guid("{ABC-123}")).to eq(obj_with_guid)
    end

    it "returns nil for non-existent guid" do
      expect(database.find_object_by_guid("{NOT-FOUND}")).to be_nil
    end
  end

  describe "#attributes_for_object" do
    let(:first_attr_for_target_obj) do
      Lutaml::Qea::Models::EaAttribute.new(
        id: 1, ea_object_id: 10, name: "attr1",
      )
    end
    let(:second_attr_for_target_obj) do
      Lutaml::Qea::Models::EaAttribute.new(
        id: 2, ea_object_id: 10, name: "attr2",
      )
    end
    let(:attr_for_other_obj) do
      Lutaml::Qea::Models::EaAttribute.new(
        id: 3, ea_object_id: 20, name: "other",
      )
    end

    before do
      database.add_collection(:attributes,
                              [first_attr_for_target_obj,
                               second_attr_for_target_obj,
                               attr_for_other_obj])
    end

    it "returns attributes for the given object_id" do
      result = database.attributes_for_object(10)
      expect(result).to contain_exactly(first_attr_for_target_obj,
                                        second_attr_for_target_obj)
    end

    it "returns empty array for object with no attributes" do
      expect(database.attributes_for_object(99)).to eq([])
    end

    it "indexes by ea_object_id not Ruby's object_id" do
      # Verify the index key comes from the model's ea_object_id attribute
      # (not from Ruby's built-in Object#object_id)
      result = database.attributes_for_object(20)
      expect(result).to eq([attr_for_other_obj])
    end
  end

  describe "#operations_for_object" do
    let(:op_for_target_obj) do
      Lutaml::Qea::Models::EaOperation.new(
        operationid: 1, ea_object_id: 10, name: "op1",
      )
    end
    let(:op_for_other_obj) do
      Lutaml::Qea::Models::EaOperation.new(
        operationid: 2, ea_object_id: 30, name: "op2",
      )
    end

    before do
      database.add_collection(:operations, [op_for_target_obj, op_for_other_obj])
    end

    it "returns operations for the given object_id" do
      expect(database.operations_for_object(10)).to eq([op_for_target_obj])
    end

    it "returns empty array when no operations" do
      expect(database.operations_for_object(99)).to eq([])
    end
  end

  describe "#operation_params_for" do
    let(:param1) do
      Lutaml::Qea::Models::EaOperationParam.new(
        operationid: 5, name: "param1",
      )
    end

    before do
      database.add_collection(:operation_params, [param1])
    end

    it "returns params for the given operationid" do
      expect(database.operation_params_for(5)).to eq([param1])
    end

    it "returns empty array when no params" do
      expect(database.operation_params_for(99)).to eq([])
    end
  end

  describe "#connectors_for_object" do
    let(:conn_start) do
      Lutaml::Qea::Models::EaConnector.new(
        connector_id: 1, start_object_id: 10, end_object_id: 20,
      )
    end
    let(:conn_end) do
      Lutaml::Qea::Models::EaConnector.new(
        connector_id: 2, start_object_id: 30, end_object_id: 10,
      )
    end

    before do
      database.add_collection(:connectors, [conn_start, conn_end])
    end

    it "returns connectors where object is start" do
      result = database.connectors_for_object(10)
      expect(result).to contain_exactly(conn_start, conn_end)
    end

    it "returns connectors where object is end only" do
      result = database.connectors_for_object(20)
      expect(result).to eq([conn_start])
    end

    it "returns empty array when no connectors" do
      expect(database.connectors_for_object(99)).to eq([])
    end
  end

  describe "#child_packages_for" do
    let(:child_pkg_alpha) do
      Lutaml::Qea::Models::EaPackage.new(
        package_id: 2, name: "Child1", parent_id: 1,
      )
    end
    let(:child_pkg_beta) do
      Lutaml::Qea::Models::EaPackage.new(
        package_id: 3, name: "Child2", parent_id: 1,
      )
    end
    let(:root_pkg) do
      Lutaml::Qea::Models::EaPackage.new(
        package_id: 1, name: "Root", parent_id: 0,
      )
    end

    before do
      database.add_collection(:packages, [root_pkg, child_pkg_alpha, child_pkg_beta])
    end

    it "returns packages with matching parent_id" do
      result = database.child_packages_for(1)
      expect(result).to contain_exactly(child_pkg_alpha, child_pkg_beta)
    end

    it "returns empty array for parent with no children" do
      expect(database.child_packages_for(99)).to eq([])
    end
  end

  describe "#objects_in_package" do
    let(:obj_in_pkg) do
      Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1, name: "Obj1", package_id: 5,
      )
    end

    before do
      database.add_collection(:objects, [obj_in_pkg])
    end

    it "returns objects with matching package_id" do
      expect(database.objects_in_package(5)).to eq([obj_in_pkg])
    end

    it "returns empty array for package with no objects" do
      expect(database.objects_in_package(99)).to eq([])
    end
  end

  describe "#diagrams_in_package" do
    let(:diag) do
      Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 1, name: "Diagram1", package_id: 5,
      )
    end

    before do
      database.add_collection(:diagrams, [diag])
    end

    it "returns diagrams with matching package_id" do
      expect(database.diagrams_in_package(5)).to eq([diag])
    end

    it "returns empty array for package with no diagrams" do
      expect(database.diagrams_in_package(99)).to eq([])
    end
  end

  describe "#find_connector" do
    let(:conn) do
      Lutaml::Qea::Models::EaConnector.new(
        connector_id: 42, start_object_id: 1, end_object_id: 2,
      )
    end

    before do
      database.add_collection(:connectors, [conn])
    end

    it "finds connector by connector_id" do
      expect(database.find_connector(42)).to eq(conn)
    end

    it "returns nil for non-existent connector_id" do
      expect(database.find_connector(99)).to be_nil
    end
  end

  describe "#find_diagram" do
    let(:diag) do
      Lutaml::Qea::Models::EaDiagram.new(
        diagram_id: 7, name: "Diagram",
      )
    end

    before do
      database.add_collection(:diagrams, [diag])
    end

    it "finds diagram by diagram_id" do
      expect(database.find_diagram(7)).to eq(diag)
    end

    it "returns nil for non-existent diagram_id" do
      expect(database.find_diagram(99)).to be_nil
    end
  end

  describe "#diagram_objects_for" do
    let(:dobj) do
      Lutaml::Qea::Models::EaDiagramObject.new(
        diagram_id: 3, ea_object_id: 10,
      )
    end

    before do
      database.add_collection(:diagram_objects, [dobj])
    end

    it "returns diagram objects for the given diagram_id" do
      expect(database.diagram_objects_for(3)).to eq([dobj])
    end

    it "returns empty array when no diagram objects" do
      expect(database.diagram_objects_for(99)).to eq([])
    end
  end

  describe "#diagram_links_for" do
    let(:dlink) do
      Lutaml::Qea::Models::EaDiagramLink.new(
        diagramid: 3,
      )
    end

    before do
      database.add_collection(:diagram_links, [dlink])
    end

    it "returns diagram links for the given diagramid" do
      expect(database.diagram_links_for(3)).to eq([dlink])
    end

    it "returns empty array when no diagram links" do
      expect(database.diagram_links_for(99)).to eq([])
    end
  end

  describe "#freeze" do
    it "freezes the database" do
      database.freeze
      expect(database).to be_frozen
    end

    it "freezes collections hash" do
      database.add_collection(:objects, [sample_object])
      database.freeze
      expect(database.collections).to be_frozen
    end

    it "prevents adding new collections after freeze" do
      database.freeze
      expect do
        database.add_collection(:new, [sample_object])
      end.to raise_error(FrozenError)
    end
  end
end
