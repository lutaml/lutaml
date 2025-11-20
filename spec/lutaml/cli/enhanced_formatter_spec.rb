# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/cli/enhanced_formatter"

RSpec.describe Lutaml::Cli::EnhancedFormatter do
  describe ".format_tree_with_icons" do
    it "formats a simple tree with icons" do
      tree = {
        name: "Root",
        type: :package,
        children: [
          { name: "Child1", type: :class, children: [] },
          { name: "Child2", type: :package, children: [] },
        ],
      }

      result = described_class.format_tree_with_icons(tree)

      expect(result).to include("Root")
      expect(result).to include("Child1")
      expect(result).to include("Child2")
      expect(result).to include(described_class::ICONS[:package])
      expect(result).to include(described_class::ICONS[:class])
    end

    it "respects show_icons configuration" do
      tree = {
        name: "Root",
        type: :package,
        children: [],
      }

      result = described_class.format_tree_with_icons(
        tree,
        { show_icons: false }
      )

      expect(result).to include("Root")
      expect(result).not_to include(described_class::ICONS[:package])
    end

    it "displays metadata when configured" do
      tree = {
        name: "Package",
        type: :package,
        count: 10,
        children: [],
      }

      result = described_class.format_tree_with_icons(
        tree,
        { show_counts: true }
      )

      expect(result).to include("10 classes")
    end

    it "handles nested structures correctly" do
      tree = {
        name: "Root",
        type: :package,
        children: [
          {
            name: "Parent",
            type: :package,
            children: [
              { name: "Child", type: :class, children: [] },
            ],
          },
        ],
      }

      result = described_class.format_tree_with_icons(tree)

      expect(result).to include("Root")
      expect(result).to include("Parent")
      expect(result).to include("Child")
    end
  end

  describe ".format_table_with_pagination" do
    let(:headers) { %w[Name Type Count] }
    let(:rows) do
      (1..100).map { |i| ["Class#{i}", "Type#{i}", i.to_s] }
    end

    it "formats small tables without pagination" do
      small_rows = rows.first(10)
      result = described_class.format_table_with_pagination(
        headers,
        small_rows,
        interactive: false
      )

      expect(result).to include("Name")
      expect(result).to include("Type")
      expect(result).to include("Count")
      expect(result).to include("Class1")
      expect(result).to include("Class10")
    end

    it "paginates large tables" do
      result = described_class.format_table_with_pagination(
        headers,
        rows,
        interactive: false,
        page_size: 50
      )

      expect(result).to include("Page 1/2")
      expect(result).to include("100 total rows")
    end

    it "shows specified page" do
      result = described_class.format_table_with_pagination(
        headers,
        rows,
        interactive: false,
        page_size: 50,
        current_page: 2
      )

      expect(result).to include("Page 2/2")
      expect(result).to include("Class51")
      expect(result).not_to include("Class10\n")
    end
  end

  describe ".format_class_details_enhanced" do
    let(:mock_class) do
      double(
        "Class",
        name: "TestClass",
        xmi_id: "test-123",
        stereotype: "entity",
        is_abstract: false,
        attributes: [
          double(
            "Attribute",
            name: "id",
            type: "Integer",
            cardinality: double("Cardinality", min: 1, max: 1)
          ),
        ],
        operations: []
      )
    end

    it "formats class details with box" do
      result = described_class.format_class_details_enhanced(mock_class)

      expect(result).to include("TestClass")
      expect(result).to include("test-123")
      expect(result).to include("entity")
      expect(result).to include("Abstract")
      expect(result).to include("No")
    end

    it "includes attributes section" do
      result = described_class.format_class_details_enhanced(mock_class)

      expect(result).to include("Attributes")
      expect(result).to include("id")
      expect(result).to include("Integer")
    end

    it "handles classes without attributes" do
      empty_class = double(
        "Class",
        name: "EmptyClass",
        attributes: [],
        operations: []
      )

      result = described_class.format_class_details_enhanced(empty_class)

      expect(result).to include("EmptyClass")
      expect(result).not_to include("Attributes")
    end
  end

  describe ".format_box" do
    it "creates a box around text" do
      result = described_class.format_box("Test Content", width: 30)

      expect(result).to include("┌")
      expect(result).to include("┐")
      expect(result).to include("└")
      expect(result).to include("┘")
      expect(result).to include("Test Content")
    end

    it "handles multi-line text" do
      result = described_class.format_box("Line 1\nLine 2", width: 30)

      expect(result).to include("Line 1")
      expect(result).to include("Line 2")
      lines = result.split("\n")
      expect(lines.size).to eq(4) # top, line1, line2, bottom
    end
  end

  describe ".format_stats_enhanced" do
    let(:stats) do
      {
        total_packages: 10,
        total_classes: 50,
        total_data_types: 5,
        total_enums: 3,
        total_diagrams: 2,
        total_attributes: 100,
        total_operations: 25,
        total_associations: 30,
        max_package_depth: 3,
        avg_package_depth: 1.5,
        avg_class_complexity: 5.2,
      }
    end

    it "formats statistics with icons" do
      result = described_class.format_stats_enhanced(stats)

      expect(result).to include("Repository Statistics")
      expect(result).to include("10")
      expect(result).to include("50")
      expect(result).to include("Packages")
      expect(result).to include("Classes")
    end

    it "includes complexity metrics when requested" do
      stats_with_complexity = stats.merge(
        most_complex_classes: [
          { name: "Complex1", total_complexity: 15 },
        ]
      )

      result = described_class.format_stats_enhanced(
        stats_with_complexity,
        show_complexity: true
      )

      expect(result).to include("Complexity Metrics")
      expect(result).to include("Complex1")
    end
  end

  describe "icon constants" do
    it "defines expected icons" do
      expect(described_class::ICONS[:package]).to eq("📦")
      expect(described_class::ICONS[:class]).to eq("📋")
      expect(described_class::ICONS[:enum]).to eq("🔢")
      expect(described_class::ICONS[:diagram]).to eq("🖼️")
    end
  end

  describe ".format_cardinality" do
    it "formats cardinality with min and max" do
      attr = double(
        "Attribute",
        cardinality: double("Cardinality", min: 0, max: "*")
      )

      result = described_class.send(:format_cardinality, attr)
      expect(result).to eq("[0..*]")
    end

    it "handles missing cardinality" do
      attr = double("Attribute", cardinality: nil)

      result = described_class.send(:format_cardinality, attr)
      expect(result).to eq("")
    end

    it "handles attributes without cardinality method" do
      attr = double("Attribute")

      result = described_class.send(:format_cardinality, attr)
      expect(result).to eq("")
    end
  end
end