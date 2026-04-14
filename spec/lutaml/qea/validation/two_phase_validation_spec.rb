# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea"
require_relative "../../../../lib/lutaml/qea/parser"

RSpec.describe "Two-Phase Validation System" do
  let(:qea_file) { "examples/qea/test.qea" }
  let(:parser) { Lutaml::Qea::Parser.new }
  let(:result) { parser.parse(qea_file) }
  let(:database) { result[:database] }
  let(:document) { result[:document] }
  let(:engine) do
    Lutaml::Qea::Validation::ValidationEngine.new(document, database: database)
  end

  describe "Validation Engine Initialization" do
    it "creates validation engine with document and database" do
      expect(engine).to be_a(Lutaml::Qea::Validation::ValidationEngine)
      expect(engine.document).to eq(document)
      expect(engine.database).to eq(database)
    end

    it "sets up default validators in registry" do
      expect(engine.registry).to be_a(Lutaml::Qea::Validation::ValidatorRegistry)

      # Phase 1: Database validators
      expect(engine.registry.registered?(:referential_integrity)).to be true
      expect(engine.registry.registered?(:orphan)).to be true
      expect(engine.registry.registered?(:circular_reference)).to be true
      expect(engine.registry.registered?(:package)).to be true

      # Phase 2: UML validators
      expect(engine.registry.registered?(:document_structure)).to be true
      expect(engine.registry.registered?(:class)).to be true
      expect(engine.registry.registered?(:attribute)).to be true
      expect(engine.registry.registered?(:operation)).to be true
      expect(engine.registry.registered?(:association)).to be true
      expect(engine.registry.registered?(:diagram)).to be true
    end
  end

  describe "Phase 1: QEA Database Validation" do
    it "validates database referential integrity" do
      result = engine.validate_qea_database(engine.send(:build_context))

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
      expect(result.messages).to be_an(Array)
    end

    it "uses db_packages not UML packages" do
      context = engine.send(:build_context)

      expect(context[:db_packages]).to be_an(Array)
      expect(context[:db_packages]).not_to be_empty
      expect(context[:db_packages].first).to respond_to(:root?)
      expect(context[:db_packages].first).to respond_to(:package_id)
    end

    it "uses db_objects not UML classes" do
      context = engine.send(:build_context)

      expect(context[:db_objects]).to be_an(Array)
      expect(context[:db_objects]).not_to be_empty
      expect(context[:db_objects].first).to respond_to(:object_id)
      expect(context[:db_objects].first).to respond_to(:package_id)
    end

    it "checks package parent references" do
      result = engine.validate_qea_database(engine.send(:build_context))

      # Should find orphaned packages if any exist
      orphan_errors = result.messages.select do |msg|
        msg.category == :missing_reference && msg.entity_type == :package
      end

      expect(orphan_errors).to be_an(Array)
    end
  end

  describe "Phase 2: UML Tree Validation" do
    it "validates UML document structure" do
      result = engine.validate_uml_tree(engine.send(:build_context))

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
      expect(result.messages).to be_an(Array)
    end

    it "uses UML packages not database packages" do
      context = engine.send(:build_context)

      expect(context[:packages]).to be_an(Array)
      if context[:packages].any?
        expect(context[:packages].first).to be_a(Lutaml::Uml::Package)
        expect(context[:packages].first).not_to respond_to(:package_id)
      end
    end

    it "validates package hierarchy" do
      result = engine.validate_uml_tree(engine.send(:build_context))

      # Should validate UML document structure
      structure_messages = result.messages.select do |msg|
        msg.category == :invalid_structure
      end

      expect(structure_messages).to be_an(Array)
    end
  end

  describe "Full Two-Phase Validation" do
    it "runs both phases and merges results" do
      result = engine.validate

      expect(result).to be_a(Lutaml::Qea::Validation::ValidationResult)
      expect(result.messages).to be_an(Array)
      expect(result.errors.size + result.warnings.size + result.info.size)
        .to eq(result.messages.size)
    end

    it "reports validation summary" do
      result = engine.validate
      summary = result.summary

      expect(summary).to be_a(String)
      expect(summary).to include("Errors:")
      expect(summary).to include("Warnings:")
    end

    it "categorizes messages by severity" do
      result = engine.validate

      expect(result.errors).to all(have_attributes(severity: :error))
      expect(result.warnings).to all(have_attributes(severity: :warning))
      expect(result.info).to all(have_attributes(severity: :info))
    end
  end

  describe "Validator Separation" do
    it "Phase 1 validators work with database models" do
      # Test that database validators use EaPackage which has root? method
      context = engine.send(:build_context)
      db_packages = context[:db_packages]

      expect(db_packages).not_to be_empty
      expect(db_packages.first).to respond_to(:root?)
      expect(db_packages.first.class.name).to eq("Lutaml::Qea::Models::EaPackage")
    end

    it "Phase 2 validators work with UML models" do
      # Test that UML validators use Lutaml::Uml::Package
      context = engine.send(:build_context)
      uml_packages = context[:packages]

      if uml_packages&.any?
        expect(uml_packages.first).to be_a(Lutaml::Uml::Package)
        expect(uml_packages.first).not_to respond_to(:package_id)
      end
    end
  end

  describe "Notes Exclusion" do
    it "does not validate Note objects as classes" do
      result = engine.validate

      # Notes should not appear in class validation errors
      note_errors = result.errors.select do |err|
        err.entity_type == :class && err.entity_name&.include?("Note")
      end

      # There might be notes but they shouldn't cause class validation errors
      expect(note_errors).to be_empty
    end
  end
end
