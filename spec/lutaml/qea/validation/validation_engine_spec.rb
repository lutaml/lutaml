# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/validation_engine"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../lib/lutaml/qea/validation/validator_registry"

RSpec.describe Lutaml::Qea::Validation::ValidationEngine do
  let(:document) { double("Document") }
  let(:database) { double("Database") }

  describe "#initialize" do
    it "creates an engine with document and database", :aggregate_failures do
      engine = described_class.new(document, database: database)

      expect(engine.document).to eq(document)
      expect(engine.database).to eq(database)
      expect(engine.registry).to be_a(Lutaml::Qea::Validation::ValidatorRegistry)
    end

    it "accepts options" do
      options = { strict: true, verbose: true }
      engine = described_class.new(document, database: database, **options)

      expect(engine.options).to include(strict: true, verbose: true)
    end

    it "sets up default validators", :aggregate_failures do
      engine = described_class.new(document, database: database)

      expect(engine.registry.registered?(:package)).to be true
      expect(engine.registry.registered?(:class)).to be true
      expect(engine.registry.registered?(:attribute)).to be true
      expect(engine.registry.registered?(:operation)).to be true
      expect(engine.registry.registered?(:association)).to be true
      expect(engine.registry.registered?(:diagram)).to be true
      expect(engine.registry.registered?(:referential_integrity)).to be true
      expect(engine.registry.registered?(:orphan)).to be true
      expect(engine.registry.registered?(:circular_reference)).to be true
    end
  end

  describe "#validate" do
    let(:engine) { described_class.new(document, database: database) }

    before do
      # Mock document methods for UML tree extraction
      allow(document).to receive_messages(classes: [], packages: [], enums: [],
                                          data_types: [], associations: [])

      # Mock database collections
      allow(database).to receive_messages(packages: [],
                                          objects: double("ObjectRepository", all: []), attributes: [], operations: [], connectors: [], diagrams: [], diagram_objects: [], diagram_links: [])
    end

    it "returns a ValidationResult" do
      result = engine.validate

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end

    it "runs all validators by default" do
      result = engine.validate

      # Result should be created (structure is valid)
      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end

    it "runs only specified validators" do
      result = engine.validate(validators: %i[package class])

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end

    it "filters results by minimum severity" do
      engine_with_filter = described_class.new(
        document,
        database: database,
        min_severity: :error,
      )

      result = engine_with_filter.validate

      # Only errors should be included
      result.messages.each do |msg|
        expect(msg.severity).to eq(:error)
      end
    end

    it "filters results by categories" do
      engine_with_filter = described_class.new(
        document,
        database: database,
        categories: [:missing_reference],
      )

      result = engine_with_filter.validate

      # Only specified categories should be included
      result.messages.each do |msg|
        expect(msg.category).to eq(:missing_reference)
      end
    end
  end

  describe "#valid?" do
    let(:engine) { described_class.new(document, database: database) }

    before do
      allow(database).to receive_messages(packages: [], objects: [],
                                          attributes: [], operations: [], connectors: [], diagrams: [], diagram_objects: [], diagram_links: [])
    end

    it "returns true when no errors" do
      # Mock document methods for this test
      allow(document).to receive_messages(classes: [], packages: [], enums: [],
                                          data_types: [], associations: [])

      expect(engine.valid?).to be true
    end
  end

  describe "#register_validator" do
    let(:engine) { described_class.new(document, database: database) }
    let(:custom_validator) do
      Class.new(Lutaml::Qea::Validation::BaseValidator) do
        def validate(_context)
          Lutaml::Qea::Validation::ValidationResult.new
        end
      end
    end

    it "registers a custom validator" do
      engine.register_validator(:custom, custom_validator)

      expect(engine.registry.registered?(:custom)).to be true
    end
  end

  describe "#validate_and_display" do
    let(:engine) { described_class.new(document, database: database) }

    before do
      # Mock document methods
      allow(document).to receive_messages(classes: [], packages: [], enums: [],
                                          data_types: [], associations: [])

      # Mock database collections
      allow(database).to receive_messages(packages: [],
                                          objects: double("ObjectRepository", all: []), attributes: [], operations: [], connectors: [], diagrams: [], diagram_objects: [], diagram_links: [])
    end

    it "validates and returns result", :aggregate_failures do
      result = nil

      expect do
        result = engine.validate_and_display(formatter: :text)
      end.to output(/VALIDATION REPORT/).to_stdout

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end
  end
end
