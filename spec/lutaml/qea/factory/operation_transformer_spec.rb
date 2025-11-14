# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/factory/operation_transformer"
require "lutaml/qea/models/ea_operation"
require "lutaml/qea/models/ea_operation_param"

RSpec.describe Lutaml::Qea::Factory::OperationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA operation to UML operation" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "getName",
        type: "String",
        scope: "Public",
        ea_guid: "{OP-GUID}",
        notes: "Returns the name"
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_op)

      expect(result).to be_a(Lutaml::Uml::Operation)
      expect(result.name).to eq("getName")
      expect(result.return_type).to eq("String")
      expect(result.visibility).to eq("public")
      expect(result.xmi_id).to eq("{OP-GUID}")
      expect(result.definition).to eq("Returns the name")
    end

    it "builds parameter type from operation parameters" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "setName"
      )

      param_row = {
        "OperationID" => 1,
        "Name" => "newName",
        "Type" => "String",
        "Kind" => "in",
        "Pos" => 0,
      }

      allow(connection).to receive(:execute)
        .with(/SELECT.*t_operationparams/, 1)
        .and_return([param_row])

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to eq("newName: String")
    end

    it "handles multiple parameters" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "calculate"
      )

      param_rows = [
        {
          "OperationID" => 1,
          "Name" => "x",
          "Type" => "Integer",
          "Kind" => "in",
          "Pos" => 0,
        },
        {
          "OperationID" => 1,
          "Name" => "y",
          "Type" => "Integer",
          "Kind" => "in",
          "Pos" => 1,
        },
      ]

      allow(connection).to receive(:execute).and_return(param_rows)

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to eq("x: Integer, y: Integer")
    end

    it "filters out return parameters" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "getValue"
      )

      param_rows = [
        {
          "OperationID" => 1,
          "Name" => "return",
          "Type" => "String",
          "Kind" => "return",
          "Pos" => 0,
        },
      ]

      allow(connection).to receive(:execute).and_return(param_rows)

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to be_nil
    end

    it "maps stereotype" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "create",
        stereotype: "constructor"
      )

      allow(connection).to receive(:execute).and_return([])

      result = transformer.transform(ea_op)

      expect(result.stereotype).to eq(["constructor"])
    end
  end
end