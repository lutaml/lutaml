# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/presenters/" \
                 "element_presenter"

RSpec.describe Lutaml::UmlRepository::Presenters::ElementPresenter do
  let(:mock_element) { double("UML Element", name: "TestElement") }
  let(:mock_repository) { double("Repository") }
  let(:presenter) { described_class.new(mock_element, mock_repository) }

  describe "#initialize" do
    it "stores element and repository", :aggregate_failures do
      expect(presenter.element).to eq(mock_element)
      expect(presenter.repository).to eq(mock_repository)
    end

    it "allows nil repository", :aggregate_failures do
      presenter_without_repo = described_class.new(mock_element)
      expect(presenter_without_repo.element).to eq(mock_element)
      expect(presenter_without_repo.repository).to be_nil
    end
  end

  describe "#to_text" do
    it "raises NotImplementedError" do
      expect { presenter.send(:to_text) }
        .to raise_error(NotImplementedError,
                        /must implement #to_text/)
    end
  end

  describe "#to_table_row" do
    it "raises NotImplementedError" do
      expect { presenter.send(:to_table_row) }
        .to raise_error(NotImplementedError,
                        /must implement #to_table_row/)
    end
  end

  describe "#to_hash" do
    it "raises NotImplementedError" do
      expect { presenter.send(:to_hash) }
        .to raise_error(NotImplementedError,
                        /must implement #to_hash/)
    end
  end

  describe "#format_cardinality" do
    it "returns empty string for nil cardinality" do
      attr = double("Attribute", cardinality: nil)
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("")
    end

    it "returns empty string for attribute without cardinality method" do
      attr = double("Attribute")
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("")
    end

    it "formats cardinality with min and max" do
      cardinality = double("Cardinality", min: "1", max: "5")
      attr = double("Attribute", cardinality: cardinality)
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("[1..5]")
    end

    it "uses 0 for nil min" do
      cardinality = double("Cardinality", min: nil, max: "5")
      attr = double("Attribute", cardinality: cardinality)
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("[0..5]")
    end

    it "uses * for nil max" do
      cardinality = double("Cardinality", min: "1", max: nil)
      attr = double("Attribute", cardinality: cardinality)
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("[1..*]")
    end

    it "uses defaults when min/max not available" do
      cardinality = double("Cardinality")
      attr = double("Attribute", cardinality: cardinality)
      result = presenter.send(:format_cardinality, attr)
      expect(result).to eq("[0..*]")
    end
  end

  describe "#truncate" do
    it "returns empty string for nil text" do
      result = presenter.send(:truncate, nil)
      expect(result).to eq("")
    end

    it "returns text unchanged if shorter than max length" do
      result = presenter.send(:truncate, "short text", 50)
      expect(result).to eq("short text")
    end

    it "returns text unchanged if equal to max length" do
      text = "a" * 50
      result = presenter.send(:truncate, text, 50)
      expect(result).to eq(text)
    end

    it "truncates long text with ellipsis", :aggregate_failures do
      text = "a" * 100
      result = presenter.send(:truncate, text, 50)
      expect(result).to eq("#{'a' * 47}...")
      expect(result.length).to eq(50)
    end

    it "uses default max length of 50" do
      text = "a" * 100
      result = presenter.send(:truncate, text)
      expect(result.length).to eq(50)
    end
  end

  describe "#extract_package_path" do
    it "extracts package path from qualified name" do
      result = presenter.send(:extract_package_path,
                              "ModelRoot::Package::ClassName")
      expect(result).to eq("ModelRoot::Package")
    end

    it "returns empty string for single component name" do
      result = presenter.send(:extract_package_path, "ClassName")
      expect(result).to eq("")
    end

    it "handles multiple levels correctly" do
      result = presenter.send(:extract_package_path,
                              "A::B::C::D::ClassName")
      expect(result).to eq("A::B::C::D")
    end

    it "handles nil input" do
      result = presenter.send(:extract_package_path, nil)
      expect(result).to eq("")
    end
  end
end
