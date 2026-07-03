# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/validation/validation_result"

RSpec.describe Lutaml::Qea::Validation::ValidationResult do
  subject(:result) { described_class.new }

  describe "#add_error" do
    it "adds an error message", :aggregate_failures do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "123",
        entity_name: "TestClass",
        message: "Test error",
      )

      expect(result.messages.size).to eq(1)
      expect(result.messages.first.severity).to eq(:error)
      expect(result.has_errors?).to be true
    end
  end

  describe "#add_warning" do
    it "adds a warning message", :aggregate_failures do
      result.add_warning(
        category: :orphaned,
        entity_type: :association,
        entity_id: "456",
        entity_name: "TestAssociation",
        message: "Test warning",
      )

      expect(result.messages.size).to eq(1)
      expect(result.messages.first.severity).to eq(:warning)
      expect(result.has_warnings?).to be true
    end
  end

  describe "#add_info" do
    it "adds an info message", :aggregate_failures do
      result.add_info(
        category: :orphaned,
        entity_type: :package,
        entity_id: "789",
        entity_name: "EmptyPackage",
        message: "Test info",
      )

      expect(result.messages.size).to eq(1)
      expect(result.messages.first.severity).to eq(:info)
      expect(result.has_info?).to be true
    end
  end

  describe "#has_errors?" do
    it "returns true when there are errors" do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "123",
        entity_name: "TestClass",
        message: "Error",
      )
      expect(result.has_errors?).to be true
    end

    it "returns false when there are no errors" do
      result.add_warning(
        category: :orphaned,
        entity_type: :class,
        entity_id: "123",
        entity_name: "TestClass",
        message: "Warning",
      )
      expect(result.has_errors?).to be false
    end
  end

  describe "#valid?" do
    it "returns true when there are no errors" do
      result.add_warning(
        category: :orphaned,
        entity_type: :class,
        entity_id: "123",
        entity_name: "TestClass",
        message: "Warning",
      )
      expect(result.valid?).to be true
    end

    it "returns false when there are errors" do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "123",
        entity_name: "TestClass",
        message: "Error",
      )
      expect(result.valid?).to be false
    end
  end

  describe "filtering methods" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error 1",
      )
      result.add_warning(
        category: :orphaned,
        entity_type: :association,
        entity_id: "2",
        entity_name: "Assoc1",
        message: "Warning 1",
      )
      result.add_info(
        category: :orphaned,
        entity_type: :package,
        entity_id: "3",
        entity_name: "Package1",
        message: "Info 1",
      )
    end

    describe "#errors" do
      it "returns only error messages", :aggregate_failures do
        expect(result.errors.size).to eq(1)
        expect(result.errors.first.severity).to eq(:error)
      end
    end

    describe "#warnings" do
      it "returns only warning messages", :aggregate_failures do
        expect(result.warnings.size).to eq(1)
        expect(result.warnings.first.severity).to eq(:warning)
      end
    end

    describe "#info" do
      it "returns only info messages", :aggregate_failures do
        expect(result.info.size).to eq(1)
        expect(result.info.first.severity).to eq(:info)
      end
    end

    describe "#by_severity" do
      it "filters by severity", :aggregate_failures do
        errors = result.by_severity(:error)
        expect(errors.size).to eq(1)
        expect(errors.first.entity_name).to eq("Class1")
      end
    end

    describe "#by_category" do
      it "filters by category", :aggregate_failures do
        orphaned = result.by_category(:orphaned)
        expect(orphaned.size).to eq(2)
        expect(orphaned.map(&:entity_type)).to contain_exactly(
          :association,
          :package,
        )
      end
    end

    describe "#by_entity_type" do
      it "filters by entity type", :aggregate_failures do
        classes = result.by_entity_type(:class)
        expect(classes.size).to eq(1)
        expect(classes.first.entity_name).to eq("Class1")
      end
    end
  end

  describe "grouping methods" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error 1",
      )
      result.add_error(
        category: :missing_reference,
        entity_type: :association,
        entity_id: "2",
        entity_name: "Assoc1",
        message: "Error 2",
      )
      result.add_warning(
        category: :orphaned,
        entity_type: :class,
        entity_id: "3",
        entity_name: "Class2",
        message: "Warning 1",
      )
    end

    describe "#grouped_by_category" do
      it "groups messages by category", :aggregate_failures do
        grouped = result.grouped_by_category
        expect(grouped.keys).to contain_exactly(
          :missing_reference,
          :orphaned,
        )
        expect(grouped[:missing_reference].size).to eq(2)
        expect(grouped[:orphaned].size).to eq(1)
      end
    end

    describe "#grouped_by_severity" do
      it "groups messages by severity", :aggregate_failures do
        grouped = result.grouped_by_severity
        expect(grouped.keys).to contain_exactly(:error, :warning)
        expect(grouped[:error].size).to eq(2)
        expect(grouped[:warning].size).to eq(1)
      end
    end

    describe "#grouped_by_entity_type" do
      it "groups messages by entity type", :aggregate_failures do
        grouped = result.grouped_by_entity_type
        expect(grouped.keys).to contain_exactly(:class, :association)
        expect(grouped[:class].size).to eq(2)
        expect(grouped[:association].size).to eq(1)
      end
    end
  end

  describe "#statistics" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error",
      )
      result.add_warning(
        category: :orphaned,
        entity_type: :association,
        entity_id: "2",
        entity_name: "Assoc1",
        message: "Warning",
      )
      result.add_info(
        category: :orphaned,
        entity_type: :package,
        entity_id: "3",
        entity_name: "Package1",
        message: "Info",
      )
    end

    it "returns summary statistics", :aggregate_failures do
      stats = result.statistics
      expect(stats[:total]).to eq(3)
      expect(stats[:errors]).to eq(1)
      expect(stats[:warnings]).to eq(1)
      expect(stats[:info]).to eq(1)
      expect(stats[:by_category]).to include(
        missing_reference: 1,
        orphaned: 2,
      )
      expect(stats[:by_entity_type]).to include(
        class: 1,
        association: 1,
        package: 1,
      )
    end
  end

  describe "#summary" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error",
      )
      result.add_warning(
        category: :orphaned,
        entity_type: :association,
        entity_id: "2",
        entity_name: "Assoc1",
        message: "Warning",
      )
    end

    it "returns a summary string", :aggregate_failures do
      summary = result.summary
      expect(summary).to include("Total Messages: 2")
      expect(summary).to include("Errors: 1")
      expect(summary).to include("Warnings: 1")
      expect(summary).to include("Info: 0")
    end
  end

  describe "#merge!" do
    it "merges another result into this one", :aggregate_failures do
      other_result = described_class.new
      other_result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "999",
        entity_name: "OtherClass",
        message: "Other error",
      )

      result.add_warning(
        category: :orphaned,
        entity_type: :package,
        entity_id: "888",
        entity_name: "Package1",
        message: "Warning",
      )

      result.merge!(other_result)

      expect(result.messages.size).to eq(2)
      expect(result.errors.size).to eq(1)
      expect(result.warnings.size).to eq(1)
    end
  end

  describe "#to_h" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error",
      )
    end

    it "returns a hash representation", :aggregate_failures do
      hash = result.to_h
      expect(hash).to have_key(:statistics)
      expect(hash).to have_key(:messages)
      expect(hash[:messages]).to be_an(Array)
      expect(hash[:messages].first).to be_a(Hash)
    end
  end

  describe "#to_json" do
    before do
      result.add_error(
        category: :missing_reference,
        entity_type: :class,
        entity_id: "1",
        entity_name: "Class1",
        message: "Error",
      )
    end

    it "returns a JSON representation", :aggregate_failures do
      json = result.to_json
      parsed = JSON.parse(json)
      expect(parsed).to have_key("statistics")
      expect(parsed).to have_key("messages")
      expect(parsed["statistics"]["total"]).to eq(1)
    end
  end
end
