# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/operation_transformer"
require_relative "../../../../lib/lutaml/qea/models/ea_operation"
require_relative "../../../../lib/lutaml/qea/models/ea_operation_param"

RSpec.describe Lutaml::Qea::Factory::OperationTransformer do
  let(:connection) { double("Connection") }
  let(:database) { double("Database", connection: connection) }
  let(:transformer) { described_class.new(database) }

  describe "#transform" do
    it "returns nil for nil input" do
      result = transformer.transform(nil)
      expect(result).to be_nil
    end

    it "transforms EA operation to UML operation", :aggregate_failures do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "getName",
        type: "String",
        scope: "Public",
        ea_guid: "{OP-GUID}",
        notes: "Returns the name",
      )

      allow(database).to receive(:operation_params_for).with(1).and_return([])

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
        name: "setName",
      )

      param = Lutaml::Qea::Models::EaOperationParam.new(
        operationid: 1,
        name: "newName",
        type: "String",
        kind: "in",
        pos: 0,
      )

      allow(database).to receive(:operation_params_for).with(1).and_return([param])

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to eq("newName: String")
    end

    it "handles multiple parameters" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "calculate",
      )

      params = [
        Lutaml::Qea::Models::EaOperationParam.new(
          operationid: 1,
          name: "x",
          type: "Integer",
          kind: "in",
          pos: 0,
        ),
        Lutaml::Qea::Models::EaOperationParam.new(
          operationid: 1,
          name: "y",
          type: "Integer",
          kind: "in",
          pos: 1,
        ),
      ]

      allow(database).to receive(:operation_params_for).with(1).and_return(params)

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to eq("x: Integer, y: Integer")
    end

    it "filters out return parameters" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "getValue",
      )

      params = [
        Lutaml::Qea::Models::EaOperationParam.new(
          operationid: 1,
          name: "return",
          type: "String",
          kind: "return",
          pos: 0,
        ),
      ]

      allow(database).to receive(:operation_params_for).with(1).and_return(params)

      result = transformer.transform(ea_op)

      expect(result.parameter_type).to be_nil
    end

    it "maps stereotype" do
      ea_op = Lutaml::Qea::Models::EaOperation.new(
        operationid: 1,
        name: "create",
        stereotype: "constructor",
      )

      allow(database).to receive(:operation_params_for).with(1).and_return([])

      result = transformer.transform(ea_op)

      expect(result.stereotype).to eq(["constructor"])
    end
  end
end
