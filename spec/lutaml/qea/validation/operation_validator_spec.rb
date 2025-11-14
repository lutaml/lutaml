# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/operation_validator"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../lib/lutaml/qea/models/ea_operation"
require_relative "../../../../lib/lutaml/qea/models/ea_object"
require_relative "../../../../lib/lutaml/qea/database"

RSpec.describe Lutaml::Qea::Validation::OperationValidator do
  let(:result) { Lutaml::Qea::Validation::ValidationResult.new }
  let(:database) do
    Lutaml::Qea::Database.new("test.qea").tap do |db|
      db.add_collection(:objects, objects)
      db.add_collection(:packages, packages)
    end
  end
  let(:context) do
    { operations: operations, database: database }
  end
  let(:validator) { described_class.new(result: result, context: context) }
  let(:packages) do
    [
      Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "TestPackage",
        parent_id: 0
      ),
    ]
  end

  describe "#validate" do
    context "with valid operations" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "doubleBetween0and1",
            object_type: "DataType",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "calculate",
            classifier: "226"
          ),
        ]
      end

      it "passes validation" do
        validator.validate
        expect(result.valid?).to be true
        expect(result.errors).to be_empty
        expect(result.warnings).to be_empty
      end
    end

    context "with classifier search by object_id (bug fix verification)" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "doubleBetween0and1",
            object_type: "DataType",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "getProbability",
            classifier: "226"
          ),
        ]
      end

      it "finds classifier by object_id (not name)" do
        validator.validate
        expect(result.warnings).to be_empty
        expect(result.valid?).to be true
      end

      it "does not create false positives for existing classifiers" do
        validator.validate
        warnings = result.warnings.select do |w|
          w.message.include?("Return type '226' not found")
        end
        expect(warnings).to be_empty
      end
    end

    context "with integer vs string classifier comparison" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "SomeType",
            object_type: "DataType",
            package_id: 1
          ),
        ]
      end

      context "when classifier is string and object_id is integer" do
        let(:operations) do
          [
            Lutaml::Qea::Models::EaOperation.new(
              operationid: 1,
              ea_object_id: 100,
              name: "operation1",
              classifier: "226"
            ),
          ]
        end

        it "matches correctly with .to_s conversion" do
          validator.validate
          expect(result.warnings).to be_empty
        end
      end

      context "when both are integers" do
        let(:operations) do
          [
            Lutaml::Qea::Models::EaOperation.new(
              operationid: 1,
              ea_object_id: 100,
              name: "operation1",
              classifier: 226
            ),
          ]
        end

        it "matches correctly with .to_s conversion" do
          validator.validate
          expect(result.warnings).to be_empty
        end
      end
    end

    context "with missing classifier reference" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "missingReturnType",
            classifier: "999"
          ),
        ]
      end

      it "reports missing classifier warning" do
        validator.validate
        expect(result.warnings.size).to eq(1)

        warning = result.warnings.first
        expect(warning.category).to eq(:missing_reference)
        expect(warning.entity_type).to eq(:operation)
        expect(warning.field).to eq("classifier")
        expect(warning.reference).to eq("999")
        expect(warning.message).to include("Return type '999' not found")
      end
    end

    context "with primitive return types" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "getString",
            classifier: "String"
          ),
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 2,
            ea_object_id: 100,
            name: "getInt",
            classifier: "Integer"
          ),
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 3,
            ea_object_id: 100,
            name: "getBool",
            classifier: "Boolean"
          ),
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 4,
            ea_object_id: 100,
            name: "doSomething",
            classifier: "void"
          ),
        ]
      end

      it "does not warn about primitive types" do
        validator.validate
        expect(result.warnings).to be_empty
        expect(result.valid?).to be true
      end
    end

    context "with missing parent object" do
      let(:objects) { [] }
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 999,
            name: "orphanOperation",
            classifier: "String"
          ),
        ]
      end

      it "reports missing parent error" do
        validator.validate
        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)

        error = result.errors.first
        expect(error.category).to eq(:missing_reference)
        expect(error.entity_type).to eq(:operation)
        expect(error.field).to eq("object_id")
        expect(error.message).to include("Parent object 999 does not exist")
      end
    end

    context "with nil or empty classifier" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "noReturnType",
            classifier: nil
          ),
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 2,
            ea_object_id: 100,
            name: "emptyReturnType",
            classifier: ""
          ),
        ]
      end

      it "does not validate nil or empty classifiers" do
        validator.validate
        expect(result.warnings).to be_empty
        expect(result.valid?).to be true
      end
    end

    context "with zero as classifier" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 0,
            name: "ZeroType",
            object_type: "DataType",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 100,
            name: "getZero",
            classifier: "0"
          ),
        ]
      end

      it "handles zero classifier correctly" do
        validator.validate
        expect(result.warnings).to be_empty
      end
    end

    context "with multiple validation issues" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1
          ),
        ]
      end
      let(:operations) do
        [
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 1,
            ea_object_id: 999,
            name: "orphan",
            classifier: "String"
          ),
          Lutaml::Qea::Models::EaOperation.new(
            operationid: 2,
            ea_object_id: 100,
            name: "badReturnType",
            classifier: "888"
          ),
        ]
      end

      it "reports all issues" do
        validator.validate
        expect(result.errors.size).to eq(1)
        expect(result.warnings.size).to eq(1)
      end
    end
  end
end