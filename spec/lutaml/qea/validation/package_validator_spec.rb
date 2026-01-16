# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/package_validator"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../lib/lutaml/qea/models/ea_package"

RSpec.describe Lutaml::Qea::Validation::PackageValidator do
  let(:result) { Lutaml::Qea::Validation::ValidationResult.new }
  let(:database) { double("Database", packages: packages) }
  let(:context) { { db_packages: packages, database: database } }
  let(:validator) { described_class.new(result: result, context: context) }

  describe "#validate" do
    context "with valid package hierarchy" do
      let(:packages) do
        [
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 1,
            name: "Root",
            parent_id: 0,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 2,
            name: "Child",
            parent_id: 1,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 3,
            name: "Grandchild",
            parent_id: 2,
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

    context "with missing parent reference" do
      let(:packages) do
        [
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 1,
            name: "Orphan",
            parent_id: 999,
          ),
        ]
      end

      it "reports missing parent error" do
        validator.validate
        expect(result.valid?).to be false
        expect(result.errors.size).to eq(1)

        error = result.errors.first
        expect(error.category).to eq(:missing_reference)
        expect(error.entity_type).to eq(:package)
        expect(error.entity_id).to eq("1")
        expect(error.field).to eq("parent_id")
        expect(error.message).to include("Parent package 999 does not exist")
      end
    end

    context "with duplicate package names in same parent" do
      let(:packages) do
        [
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 1,
            name: "Root",
            parent_id: 0,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 2,
            name: "Duplicate",
            parent_id: 1,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 3,
            name: "Duplicate",
            parent_id: 1,
          ),
        ]
      end

      it "reports duplicate name warnings" do
        validator.validate
        expect(result.warnings.size).to eq(2)

        warnings = result.warnings
        expect(warnings.all? { |w| w.category == :duplicate }).to be true
        expect(warnings.all? { |w| w.field == "name" }).to be true
        expect(warnings.first.message).to include("Duplicate package name")
      end
    end

    xcontext "with circular hierarchy" do
      let(:packages) do
        [
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 1,
            name: "A",
            parent_id: 3,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 2,
            name: "B",
            parent_id: 1,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 3,
            name: "C",
            parent_id: 2,
          ),
        ]
      end

      it "reports circular reference error" do
        validator.validate
        expect(result.valid?).to be false

        circular_errors = result.errors.select do |e|
          e.category == :circular_reference
        end
        expect(circular_errors).not_to be_empty
        expect(circular_errors.first.message).to include("Circular package")
      end
    end

    context "with multiple validation issues" do
      let(:packages) do
        [
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 1,
            name: "Root",
            parent_id: 999,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 2,
            name: "Dup",
            parent_id: 0,
          ),
          Lutaml::Qea::Models::EaPackage.new(
            package_id: 3,
            name: "Dup",
            parent_id: 0,
          ),
        ]
      end

      it "reports all issues" do
        validator.validate
        expect(result.errors.size).to eq(1)
        expect(result.warnings.size).to eq(2)
      end
    end
  end
end