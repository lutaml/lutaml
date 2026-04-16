# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/attribute_validator"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../lib/lutaml/qea/models/ea_attribute"
require_relative "../../../../lib/lutaml/qea/models/ea_object"
require_relative "../../../../lib/lutaml/qea/database"

RSpec.describe Lutaml::Qea::Validation::AttributeValidator do
  let(:result) { Lutaml::Qea::Validation::ValidationResult.new }
  let(:database) do
    Lutaml::Qea::Database.new("test.qea").tap do |db|
      db.add_collection(:objects, objects)
      db.add_collection(:packages, packages)
    end
  end
  let(:context) do
    { attributes: attributes, database: database }
  end
  let(:validator) { described_class.new(result: result, context: context) }
  let(:packages) do
    [
      Lutaml::Qea::Models::EaPackage.new(
        package_id: 1,
        name: "TestPackage",
        parent_id: 0,
      ),
    ]
  end

  describe "#validate" do
    context "with valid attributes" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1,
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "doubleBetween0and1",
            object_type: "DataType",
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "testAttr",
            classifier: "226",
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
            package_id: 1,
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "doubleBetween0and1",
            object_type: "DataType",
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "probability",
            classifier: "226",
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
          w.message.include?("Classifier '226' not found")
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
            package_id: 1,
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 226,
            name: "SomeType",
            object_type: "DataType",
            package_id: 1,
          ),
        ]
      end

      context "when classifier is string and object_id is integer" do
        let(:attributes) do
          [
            Lutaml::Qea::Models::EaAttribute.new(
              id: 1,
              ea_object_id: 100,
              name: "attr1",
              classifier: "226",
            ),
          ]
        end

        it "matches correctly with .to_s conversion" do
          validator.validate
          expect(result.warnings).to be_empty
        end
      end

      context "when both are integers" do
        let(:attributes) do
          [
            Lutaml::Qea::Models::EaAttribute.new(
              id: 1,
              ea_object_id: 100,
              name: "attr1",
              classifier: 226,
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
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "missingTypeAttr",
            classifier: "999",
          ),
        ]
      end

      it "reports missing classifier warning" do
        validator.validate
        expect(result.warnings.size).to eq(1)

        warning = result.warnings.first
        expect(warning.category).to eq(:missing_reference)
        expect(warning.entity_type).to eq(:attribute)
        expect(warning.field).to eq("classifier")
        expect(warning.reference).to eq("999")
        expect(warning.message).to include("Classifier '999' not found")
      end
    end

    context "with primitive types" do
      let(:objects) do
        [
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 100,
            name: "TestClass",
            object_type: "Class",
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "stringAttr",
            classifier: "String",
          ),
          Lutaml::Qea::Models::EaAttribute.new(
            id: 2,
            ea_object_id: 100,
            name: "intAttr",
            classifier: "Integer",
          ),
          Lutaml::Qea::Models::EaAttribute.new(
            id: 3,
            ea_object_id: 100,
            name: "boolAttr",
            classifier: "Boolean",
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
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 999,
            name: "orphanAttr",
            classifier: "String",
          ),
        ]
      end

      it "reports missing parent error" do
        validator.validate
        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)

        error = result.errors.first
        expect(error.category).to eq(:missing_reference)
        expect(error.entity_type).to eq(:attribute)
        expect(error.field).to eq("ea_object_id")
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
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "noTypeAttr",
            classifier: nil,
          ),
          Lutaml::Qea::Models::EaAttribute.new(
            id: 2,
            ea_object_id: 100,
            name: "emptyTypeAttr",
            classifier: "",
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
            package_id: 1,
          ),
          Lutaml::Qea::Models::EaObject.new(
            ea_object_id: 0,
            name: "ZeroType",
            object_type: "DataType",
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 100,
            name: "zeroAttr",
            classifier: "0",
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
            package_id: 1,
          ),
        ]
      end
      let(:attributes) do
        [
          Lutaml::Qea::Models::EaAttribute.new(
            id: 1,
            ea_object_id: 999,
            name: "orphan",
            classifier: "String",
          ),
          Lutaml::Qea::Models::EaAttribute.new(
            id: 2,
            ea_object_id: 100,
            name: "badType",
            classifier: "888",
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
