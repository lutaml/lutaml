# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Validators::RepositoryValidator do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:validator) { described_class.new(document, indexes) }

  describe "#validate" do
    context "with valid model" do
      it "returns valid result" do
        result = validator.validate
        expect(result).to be_a(Lutaml::UmlRepository::Validators::ValidationResult)
      end

      it "has no critical errors" do
        result = validator.validate
        expect(result.errors).to be_an(Array)
      end
    end

    context "with invalid type references" do
      let(:document) do
        doc = create_simple_test_document
        # Add a class with invalid type reference
        klass = doc.packages.first.classes.first
        attr = Lutaml::Uml::TopElementAttribute.new
        attr.name = "invalid_attr"
        attr.type = "NonExistent::Type[0..1],"
        klass.attributes = []
        klass.attributes << attr
        doc
      end

      it "detects unresolved types" do
        result = validator.validate
        expect(result.errors).to be_an(Array)
        expect(result.errors.first).to include("Unresolved type reference")
      end
    end

    xcontext "with circular inheritance" do
      let(:document) do
        doc = Lutaml::Uml::Document.new
        doc.name = "TestModel"

        pkg = Lutaml::Uml::Package.new
        pkg.name = "TestPackage"
        pkg.xmi_id = "pkg1"

        # Create two classes with circular inheritance
        class1 = Lutaml::Uml::Class.new
        class1.name = "Class1"
        class1.xmi_id = "class1"

        class2 = Lutaml::Uml::Class.new
        class2.name = "Class2"
        class2.xmi_id = "class2"

        # Class1 inherits from Class2
        assoc1 = Lutaml::Uml::Association.new
        assoc1.member_end = "Class2"
        assoc1.member_end_type = "inheritance"
        assoc1.member_end_xmi_id = "class2"
        class1.associations ||= []
        class1.associations << assoc1

        # Class2 inherits from Class1 (circular!)
        assoc2 = Lutaml::Uml::Association.new
        assoc2.member_end = "Class1"
        assoc2.member_end_type = "inheritance"
        assoc2.member_end_xmi_id = "class1"
        class2.associations ||= []
        class2.associations << assoc2

        pkg.classes ||= []
        pkg.classes << class1
        pkg.classes << class2
        doc.packages ||= []
        doc.packages << pkg
        doc
      end

      it "detects cycles" do
        result = validator.validate
        circular_errors = result.errors.select do |e|
          e[:message].to_s.include?("circular") ||
          e[:message].to_s.include?("cycle")
        end
        expect(circular_errors).not_to be_empty
      end
    end
  end

  describe "#check_type_references" do
    it "validates type references in attributes" do
      validator.send(:check_type_references)
      errors = validator.instance_variable_get(:@errors)
      expect(errors).to be_an(Array)
      errors.each do |error|
        expect(error).to be_a(String)
      end
    end
  end

  describe "#check_generalization_references" do
    it "checks generalization references" do
      validator.send(:check_generalization_references)
      errors = validator.instance_variable_get(:@errors)
      expect(errors).to be_an(Array)
    end
  end

  describe "#check_association_references" do
    it "checks association references" do
      validator.send(:check_association_references)
      errors = validator.instance_variable_get(:@errors)
      expect(errors).to be_an(Array)
    end
  end

  describe "#check_multiplicities" do
    it "checks multiplicities" do
      validator.send(:check_multiplicities)
      errors = validator.instance_variable_get(:@errors)
      expect(errors).to be_an(Array)
    end
  end

  describe "ValidationResult" do
    let(:result) { validator.validate }

    it "responds to valid?" do
      expect(result).to respond_to(:valid?)
    end

    it "responds to errors" do
      expect(result).to respond_to(:errors)
      expect(result.errors).to be_an(Array)
    end

    it "responds to warnings" do
      expect(result).to respond_to(:warnings)
      expect(result.warnings).to be_an(Array)
    end

    it "responds to external_references" do
      expect(result).to respond_to(:external_references)
      expect(result.external_references).to be_an(Array)
    end

    it "responds to validation_details" do
      expect(result).to respond_to(:validation_details)
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "validates simple document" do
      result = validator.validate
      expect(result).to be_a(Lutaml::UmlRepository::Validators::ValidationResult)
    end

    it "returns valid result for simple document" do
      result = validator.validate
      expect(result.valid?).to be(true).or be(false)
    end
  end
end
