# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/class_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_object"

RSpec.describe Lutaml::Qea::Factory::ClassTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "returns nil for non-class objects" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        object_type: "Package",
      )

      result = transformer.transform(ea_obj)

      expect(result).to be_nil
    end

    it "transforms EA class object to UML class", :aggregate_failures do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Building",
        ea_guid: "{CLASS-GUID}",
        abstract: "0",
        visibility: "Public",
        note: "Represents a building",
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([])
      allow(database).to receive(:operations_for_object).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, tagged_values: [],
                                          attribute_tags: [], object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result).to be_a(Lutaml::Uml::Class)
      expect(result.name).to eq("Building")
      expect(result.xmi_id).to eq("EAID_CLASS_GUID")
      expect(result.is_abstract).to be false
      expect(result.visibility).to eq("public")
      expect(result.definition).to eq("Represents a building")
    end

    it "marks abstract classes" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Shape",
        abstract: "1",
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([])
      allow(database).to receive(:operations_for_object).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, tagged_values: [],
                                          attribute_tags: [], object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result.is_abstract).to be true
    end

    it "adds interface stereotype for interfaces" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Interface",
        name: "IDrawable",
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([])
      allow(database).to receive(:operations_for_object).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, tagged_values: [],
                                          attribute_tags: [], object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result.stereotype).to include("interface")
    end

    it "loads and transforms attributes", :aggregate_failures do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Person",
      )

      ea_attr = Lutaml::Qea::Models::EaAttribute.new(
        id: 1,
        object_id: 1,
        name: "firstName",
        type: "String",
        scope: "Private",
        pos: 0,
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([ea_attr])
      allow(database).to receive(:operations_for_object).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, attribute_tags: [],
                                          object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result.attributes.size).to eq(1)
      expect(result.attributes.first.name).to eq("firstName")
    end

    it "loads and transforms operations", :aggregate_failures do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Calculator",
      )

      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        object_id: 1,
        name: "add",
        type: "Integer",
        scope: "Public",
        pos: 0,
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([])
      allow(database).to receive(:operations_for_object).with(1).and_return([ea_op])
      allow(database).to receive(:operation_params_for).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, attribute_tags: [],
                                          object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result.operations.size).to eq(1)
      expect(result.operations.first.name).to eq("add")
    end

    it "preserves stereotype" do
      ea_obj = Lutaml::Qea::Models::EaObject.new(
        ea_object_id: 1,
        object_type: "Class",
        name: "Entity",
        stereotype: "entity",
      )

      allow(database).to receive(:attributes_for_object).with(1).and_return([])
      allow(database).to receive(:operations_for_object).with(1).and_return([])
      allow(database).to receive(:connectors_for_object).with(1).and_return([])
      allow(database).to receive(:find_object).with(1).and_return(ea_obj)
      allow(database).to receive_messages(xrefs: nil, tagged_values: [],
                                          attribute_tags: [], object_constraints: [], object_properties: [], find_package: nil)

      result = transformer.transform(ea_obj)

      expect(result.stereotype).to eq(["entity"])
    end
  end
end
