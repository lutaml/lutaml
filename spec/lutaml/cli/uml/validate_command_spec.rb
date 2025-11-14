# frozen_string_literal: true

require "spec_helper"
require "lutaml/cli"

RSpec.describe "CLI UML Validate Command" do
  let(:qea_file) { "examples/qea/test.qea" }

  describe "validate command" do
    it "runs without errors on valid QEA file" do
      # This is a regression test for the bug:
      # "undefined method `root?` for an instance of Lutaml::Uml::Package"
      #
      # The bug was caused by database validators (PackageValidator,
      # ReferentialIntegrityValidator, etc.) being called on UML Package
      # instances instead of database EaPackage instances.
      #
      # This spec ensures the validation system properly separates:
      # - Phase 1: Database validators use db_packages (EaPackage)
      # - Phase 2: UML validators use packages (Lutaml::Uml::Package)

      expect do
        parser = Lutaml::Qea::Parser.new
        result = parser.parse(qea_file)

        engine = Lutaml::Qea::Validation::ValidationEngine.new(
          result[:document],
          database: result[:database]
        )

        validation_result = engine.validate

        # Should complete without raising errors
        expect(validation_result).to be_a(Lutaml::Qea::Validation::ValidationResult)
      end.not_to raise_error
    end

    it "validates database models have expected methods" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)
      database = result[:database]

      # Database packages should have root? and package_id methods
      expect(database.packages).not_to be_empty
      expect(database.packages.first).to respond_to(:root?)
      expect(database.packages.first).to respond_to(:package_id)
      expect(database.packages.first).to respond_to(:parent_id)
    end

    it "validates UML models have expected structure" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)
      document = result[:document]

      # UML packages should be Lutaml::Uml::Package instances
      if document.packages && document.packages.any?
        expect(document.packages.first).to be_a(Lutaml::Uml::Package)
        expect(document.packages.first).to respond_to(:name)
        expect(document.packages.first).to respond_to(:classes)

        # UML packages should NOT have database-specific methods
        expect(document.packages.first).not_to respond_to(:package_id)
      end
    end

    it "properly separates database and UML validation contexts" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      context = engine.send(:build_context)

      # Context should have both db_ and non-db versions
      expect(context).to have_key(:db_packages)
      expect(context).to have_key(:packages)
      expect(context).to have_key(:db_objects)

      # They should be different types
      if context[:db_packages] && context[:db_packages].any?
        expect(context[:db_packages].first.class.name).to eq("Lutaml::Qea::Models::EaPackage")
      end

      if context[:packages] && context[:packages].any?
        expect(context[:packages].first).to be_a(Lutaml::Uml::Package)
      end
    end

    it "runs all validators without method errors" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      # Should not raise NoMethodError
      expect { engine.validate }.not_to raise_error(NoMethodError)
    end

    it "Phase 1 validators use database models" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      context = engine.send(:build_context)

      # Run Phase 1 validators
      expect do
        engine.validate_qea_database(context)
      end.not_to raise_error
    end

    it "Phase 2 validators use UML models" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      context = engine.send(:build_context)

      # Run Phase 2 validators
      expect do
        engine.validate_uml_tree(context)
      end.not_to raise_error
    end
  end

  describe "validation result format" do
    it "provides structured validation results" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      validation_result = engine.validate

      expect(validation_result.errors).to be_an(Array)
      expect(validation_result.warnings).to be_an(Array)
      expect(validation_result.info).to be_an(Array)
      expect(validation_result.summary).to be_a(String)
    end

    it "categorizes messages correctly" do
      parser = Lutaml::Qea::Parser.new
      result = parser.parse(qea_file)

      engine = Lutaml::Qea::Validation::ValidationEngine.new(
        result[:document],
        database: result[:database]
      )

      validation_result = engine.validate

      validation_result.errors.each do |error|
        expect(error.severity).to eq(:error)
        expect(error).to respond_to(:category)
        expect(error).to respond_to(:entity_type)
        expect(error).to respond_to(:message)
      end
    end
  end
end