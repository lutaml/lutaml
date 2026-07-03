# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/statistics_calculator"

RSpec.describe Lutaml::UmlRepository::StatisticsCalculator do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:calculator) { described_class.new(document, indexes) }

  describe "#calculate" do
    let(:stats) { calculator.calculate }

    it "returns hash with all statistics" do
      expect(stats).to be_a(Hash)
    end

    it "includes basic counts", :aggregate_failures do
      expect(stats).to have_key(:total_packages)
      expect(stats).to have_key(:total_classes)
      expect(stats).to have_key(:total_enums)
      expect(stats).to have_key(:total_data_types)
      expect(stats).to have_key(:total_diagrams)
      expect(stats).to have_key(:total_associations)
    end

    it "includes packages_by_depth", :aggregate_failures do
      expect(stats).to have_key(:packages_by_depth)
      expect(stats[:packages_by_depth]).to be_a(Hash)
    end

    it "includes classes_by_stereotype", :aggregate_failures do
      expect(stats).to have_key(:classes_by_stereotype)
      expect(stats[:classes_by_stereotype]).to be_a(Hash)
    end

    it "includes most_complex_classes", :aggregate_failures do
      expect(stats).to have_key(:most_complex_classes)
      expect(stats[:most_complex_classes]).to be_an(Array)
    end

    it "calculates correct total packages" do
      total_packages = indexes[:package_paths].values.length
      expect(stats[:total_packages]).to eq(total_packages)
    end

    it "calculates correct total classes" do
      total_classes = indexes[:qualified_names].values.count do |e|
        e.is_a?(Lutaml::Uml::Class)
      end
      expect(stats[:total_classes]).to eq(total_classes)
    end

    it "calculates correct total enums" do
      total_enums = indexes[:qualified_names].values.count do |e|
        e.is_a?(Lutaml::Uml::Enum)
      end
      expect(stats[:total_enums]).to eq(total_enums)
    end

    it "calculates correct total data types" do
      total_data_types = indexes[:qualified_names].values.count do |e|
        e.is_a?(Lutaml::Uml::DataType)
      end
      expect(stats[:total_data_types]).to eq(total_data_types)
    end

    it "calculates packages by depth correctly", :aggregate_failures do
      packages_by_depth = stats[:packages_by_depth]

      packages_by_depth.each do |depth, count|
        expect(depth).to be_an(Integer)
        expect(count).to be_an(Integer)
        expect(count).to be > 0
      end
    end

    it "groups classes by stereotype correctly", :aggregate_failures do
      classes_by_stereotype = stats[:classes_by_stereotype]

      classes_by_stereotype.each_value do |count|
        expect(count).to be_an(Integer)
        expect(count).to be > 0
      end
    end

    it "identifies most complex classes", :aggregate_failures do
      most_complex = stats[:most_complex_classes]

      most_complex.each do |item|
        expect(item).to be_a(Hash)
        expect(item).to have_key(:class)
        expect(item).to have_key(:complexity)
        expect(item[:class]).to be_a(Lutaml::Uml::Class)
        expect(item[:complexity]).to be_an(Integer)
      end
    end

    it "limits most complex classes to specified number" do
      most_complex = stats[:most_complex_classes]
      expect(most_complex.length).to be <= 10
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }
    let(:stats) { calculator.calculate }

    it "calculates statistics for simple document", :aggregate_failures do
      expect(stats).to be_a(Hash)
      expect(stats[:total_packages]).to eq(3)
      expect(stats[:total_classes]).to eq(1)
      expect(stats[:total_enums]).to eq(1)
    end

    it "groups packages by depth", :aggregate_failures do
      packages_by_depth = stats[:packages_by_depth]

      expect(packages_by_depth[0]).to eq(1)
      expect(packages_by_depth[1]).to eq(1)
      expect(packages_by_depth[2]).to eq(1)
    end

    it "groups classes by stereotype" do
      classes_by_stereotype = stats[:classes_by_stereotype]

      expect(classes_by_stereotype["TestStereotype"]).to eq(1)
    end

    it "calculates complexity correctly", :aggregate_failures do
      most_complex = stats[:most_complex_classes]

      expect(most_complex.length).to eq(1)
      expect(most_complex.first[:class].name).to eq("TestClass")
    end
  end

  describe "#total_attributes" do
    it "counts total attributes across all classes", :aggregate_failures do
      total = calculator.send(:total_attributes)
      expect(total).to be_an(Integer)
      expect(total).to be >= 0
    end
  end

  describe "#total_operations" do
    it "counts total operations across all classes", :aggregate_failures do
      total = calculator.send(:total_operations)
      expect(total).to be_an(Integer)
      expect(total).to be >= 0
    end
  end

  describe "#class_complexity" do
    it "calculates complexity for a class", :aggregate_failures do
      klass = indexes[:qualified_names].values.find do |e|
        e.is_a?(Lutaml::Uml::Class)
      end

      if klass
        complexity = calculator.send(:class_complexity, klass)
        expect(complexity).to be_an(Integer)
        expect(complexity).to be >= 0
      end
    end

    it "includes attributes in complexity" do
      klass = Lutaml::Uml::Class.new
      klass.name = "TestClass"
      klass.attributes = [
        Lutaml::Uml::TopElementAttribute.new,
        Lutaml::Uml::TopElementAttribute.new,
      ]

      complexity = calculator.send(:class_complexity, klass)
      expect(complexity).to be >= 2
    end
  end
end
