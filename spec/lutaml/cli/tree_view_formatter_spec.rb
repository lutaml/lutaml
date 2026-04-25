# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/tree_view_formatter"
require_relative "../../../lib/lutaml/uml_repository/repository"

RSpec.describe Lutaml::Cli::TreeViewFormatter do
  let(:formatter) { described_class.new(options) }
  let(:options) { {} }

  describe "#format" do
    context "with a simple repository" do
      let(:repository) do
        # Create a mock repository for testing
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 5,
            total_classes: 20,
            total_diagrams: 3,
          },
        )
      end

      it "formats the repository as a tree", :aggregate_failures do
        output = formatter.format(repository)
        expect(output).to include("ModelRoot")
        expect(output).to include("Statistics")
      end

      it "includes statistics at the end", :aggregate_failures do
        output = formatter.format(repository)
        expect(output).to include("Total Packages: 5")
        expect(output).to include("Total Classes: 20")
        expect(output).to include("Total Diagrams: 3")
      end
    end

    context "with no_color option" do
      let(:options) { { no_color: true } }
      let(:repository) do
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 1,
            total_classes: 1,
            total_diagrams: 1,
          },
        )
      end

      it "formats without colors" do
        output = formatter.format(repository)
        # Output should not contain ANSI color codes
        expect(output).not_to match(/\e\[/)
      end
    end

    context "with max_depth option" do
      let(:options) { { max_depth: 1 } }
      let(:repository) do
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 0,
            total_classes: 0,
            total_diagrams: 0,
          },
        )
      end

      it "respects max depth" do
        output = formatter.format(repository)
        expect(output).to include("ModelRoot")
      end
    end

    context "with show_attributes option disabled" do
      let(:options) { { show_attributes: false } }
      let(:repository) do
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 0,
            total_classes: 0,
            total_diagrams: 0,
          },
        )
      end

      it "does not show attributes" do
        formatter = described_class.new(options)
        expect(formatter.instance_variable_get(:@show_attributes)).to be false
      end
    end

    context "with show_operations option disabled" do
      let(:options) { { show_operations: false } }
      let(:repository) do
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 0,
            total_classes: 0,
            total_diagrams: 0,
          },
        )
      end

      it "does not show operations" do
        formatter = described_class.new(options)
        expect(formatter.instance_variable_get(:@show_operations)).to be false
      end
    end

    context "with show_associations option enabled" do
      let(:options) { { show_associations: true } }
      let(:repository) do
        double(
          "UmlRepository",
          list_packages: [],
          statistics: {
            total_packages: 0,
            total_classes: 0,
            total_diagrams: 0,
          },
        )
      end

      it "shows associations" do
        formatter = described_class.new(options)
        expect(formatter.instance_variable_get(:@show_associations)).to be true
      end
    end
  end

  describe "color scheme" do
    it "defines colors for all element types" do
      expect(described_class::COLORS).to include(
        package: :cyan,
        class: :green,
        interface: :magenta,
        enumeration: :yellow,
        attribute: "#FFD700",
        operation: "#87CEEB",
        association: :white,
        diagram: "#DDA0DD",
        statistics: "#ADD8E6",
      )
    end
  end

  describe "icons" do
    it "defines icons for element types" do
      expect(described_class::ICONS).to include(
        package: "📦",
        class: "📦",
        interface: "🔌",
        enumeration: "🔢",
        attribute: "🔹",
        operation: "🔧",
        association: "🔗",
        diagram: "📊",
      )
    end
  end

  describe "tree characters" do
    it "defines tree drawing characters" do
      expect(described_class::TREE_CHARS).to include(
        vertical: "│",
        branch: "├──",
        last_branch: "└──",
        space: "   ",
        continuation: "│  ",
      )
    end
  end
end
