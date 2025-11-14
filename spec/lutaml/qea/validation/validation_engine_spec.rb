# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/validation_engine"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"
require_relative "../../../../lib/lutaml/qea/validation/validator_registry"

RSpec.describe Lutaml::Qea::Validation::ValidationEngine do
  let(:document) { double("Document") }
  let(:database) { double("Database") }

  describe "#initialize" do
    it "creates an engine with document and database" do
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

    it "sets up default validators" do
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
      # Mock database collections
      allow(database).to receive(:packages).and_return([])
      allow(database).to receive(:objects).and_return([])
      allow(database).to receive(:attributes).and_return([])
      allow(database).to receive(:operations).and_return([])
      allow(database).to receive(:connectors).and_return([])
      allow(database).to receive(:diagrams).and_return([])
      allow(database).to receive(:diagram_objects).and_return([])
      allow(database).to receive(:diagram_links).and_return([])
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
      result = engine.validate(validators: [:package, :class])

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end

    it "filters results by minimum severity" do
      engine_with_filter = described_class.new(
        document,
        database: database,
        min_severity: :error
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
        categories: [:missing_reference]
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
      allow(database).to receive(:packages).and_return([])
      allow(database).to receive(:objects).and_return([])
      allow(database).to receive(:attributes).and_return([])
      allow(database).to receive(:operations).and_return([])
      allow(database).to receive(:connectors).and_return([])
      allow(database).to receive(:diagrams).and_return([])
      allow(database).to receive(:diagram_objects).and_return([])
      allow(database).to receive(:diagram_links).and_return([])
    end

    it "returns true when no errors" do
      expect(engine.valid?).to be true
    end
  end

  describe "#register_validator" do
    let(:engine) { described_class.new(document, database: database) }
    let(:custom_validator) do
      Class.new(Lutaml::Qea::Validation::BaseValidator) do
        def validate(context)
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
      allow(database).to receive(:packages).and_return([])
      allow(database).to receive(:objects).and_return([])
      allow(database).to receive(:attributes).and_return([])
      allow(database).to receive(:operations).and_return([])
      allow(database).to receive(:connectors).and_return([])
      allow(database).to receive(:diagrams).and_return([])
      allow(database).to receive(:diagram_objects).and_return([])
      allow(database).to receive(:diagram_links).and_return([])
    end

    it "validates and returns result" do
      result = nil

      expect do
        result = engine.validate_and_display(formatter: :text)
      end.to output(/VALIDATION REPORT/).to_stdout

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
    end
  end
end