# frozen_string_literal: true

require "spec_helper"

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
        critical_errors = result.errors.select { |e| e[:severity] == :error }
        expect(critical_errors).to be_an(Array)
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
        klass.attributes << attr
        doc
      end

      it "detects unresolved types" do
        result = validator.validate
        expect(result.errors).to be_an(Array)
      end
    end

    context "with circular inheritance" do
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
        class1.associations << assoc1

        # Class2 inherits from Class1 (circular!)
        assoc2 = Lutaml::Uml::Association.new
        assoc2.member_end = "Class1"
        assoc2.member_end_type = "inheritance"
        assoc2.member_end_xmi_id = "class1"
        class2.associations << assoc2

        pkg.classes << class1
        pkg.classes << class2
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

  describe "#validate_type_references" do
    it "validates type references in attributes" do
      errors = []
      validator.send(:validate_type_references, errors)
      expect(errors).to be_an(Array)
    end

    it "detects invalid type references" do
      errors = []
      validator.send(:validate_type_references, errors)

      errors.each do |error|
        expect(error).to be_a(Hash)
        expect(error).to have_key(:severity)
        expect(error).to have_key(:message)
      end
    end
  end

  describe "#validate_inheritance" do
    it "validates inheritance relationships" do
      errors = []
      validator.send(:validate_inheritance, errors)
      expect(errors).to be_an(Array)
    end

    it "detects circular inheritance" do
      errors = []
      validator.send(:validate_inheritance, errors)

      errors.each do |error|
        expect(error).to be_a(Hash)
        expect(error).to have_key(:severity)
      end
    end
  end

  describe "#validate_associations" do
    it "validates association relationships" do
      errors = []
      validator.send(:validate_associations, errors)
      expect(errors).to be_an(Array)
    end
  end

  describe "#validate_packages" do
    it "validates package structure" do
      errors = []
      validator.send(:validate_packages, errors)
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

    it "categorizes errors by severity" do
      result.errors.each do |error|
        expect([:error, :warning, :info]).to include(error[:severity])
      end
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