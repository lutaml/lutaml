# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/xsd/coverage_analyzer"

RSpec.describe Lutaml::Xsd::CoverageAnalyzer do
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }

  before do
    # Create a simple test schema structure
    # We'll use mock data to test the coverage analysis logic
    allow(repository).to receive(:instance_variable_get).with(:@type_index).and_return(type_index)
    allow(repository).to receive(:find_type) do |qname|
      find_mock_type(qname)
    end
  end

  let(:type_index) do
    index = instance_double("TypeIndex")
    allow(index).to receive(:all).and_return(all_types_data)
    index
  end

  let(:all_types_data) do
    {
      "{http://example.com/ns}TypeA" => {
        namespace: "http://example.com/ns",
        definition: double(name: "TypeA"),
        type: :complex_type,
      },
      "{http://example.com/ns}TypeB" => {
        namespace: "http://example.com/ns",
        definition: double(name: "TypeB"),
        type: :complex_type,
      },
      "{http://example.com/ns}TypeC" => {
        namespace: "http://example.com/ns",
        definition: double(name: "TypeC"),
        type: :simple_type,
      },
      "{http://other.com/ns}TypeD" => {
        namespace: "http://other.com/ns",
        definition: double(name: "TypeD"),
        type: :complex_type,
      },
    }
  end

  def find_mock_type(qname)
    case qname
    when "ns:TypeA"
      Lutaml::Xsd::TypeResolutionResult.success(
        qname: qname,
        namespace: "http://example.com/ns",
        local_name: "TypeA",
        definition: double(name: "TypeA"),
        schema_file: "test.xsd",
        resolution_path: [],
      )
    when "ns:TypeB"
      Lutaml::Xsd::TypeResolutionResult.success(
        qname: qname,
        namespace: "http://example.com/ns",
        local_name: "TypeB",
        definition: double(name: "TypeB"),
        schema_file: "test.xsd",
        resolution_path: [],
      )
    when "ns:TypeC"
      Lutaml::Xsd::TypeResolutionResult.success(
        qname: qname,
        namespace: "http://example.com/ns",
        local_name: "TypeC",
        definition: double(name: "TypeC"),
        schema_file: "test.xsd",
        resolution_path: [],
      )
    when "other:TypeD"
      Lutaml::Xsd::TypeResolutionResult.success(
        qname: qname,
        namespace: "http://other.com/ns",
        local_name: "TypeD",
        definition: double(name: "TypeD"),
        schema_file: "test.xsd",
        resolution_path: [],
      )
    else
      Lutaml::Xsd::TypeResolutionResult.failure(
        qname: qname,
        error_message: "Type not found",
        resolution_path: [],
      )
    end
  end

  describe "#initialize" do
    it "creates analyzer with repository" do
      analyzer = described_class.new(repository)
      expect(analyzer.repository).to eq(repository)
    end
  end

  describe "#analyze" do
    let(:analyzer) { described_class.new(repository) }
    let(:dependency_grapher) { instance_double(Lutaml::Xsd::DependencyGrapher) }

    before do
      allow(Lutaml::Xsd::DependencyGrapher).to receive(:new).with(repository).and_return(dependency_grapher)
      allow(dependency_grapher).to receive(:extract_type_references)
        .with(anything)
        .and_return([])
    end

    context "with no entry types" do
      it "returns report with all types unused" do
        report = analyzer.analyze(entry_types: [])

        expect(report).to be_a(Lutaml::Xsd::CoverageReport)
        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(0)
        expect(report.unused_count).to eq(4)
        expect(report.coverage_percentage).to eq(0.0)
      end
    end

    context "with single entry type" do
      it "marks entry type as used" do
        report = analyzer.analyze(entry_types: ["ns:TypeA"])

        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(1)
        expect(report.unused_count).to eq(3)
        expect(report.coverage_percentage).to eq(25.0)
        expect(report.entry_types).to eq(["ns:TypeA"])
      end
    end

    context "with multiple entry types" do
      it "marks all entry types as used" do
        report = analyzer.analyze(entry_types: ["ns:TypeA", "ns:TypeB"])

        expect(report.total_types).to eq(4)
        expect(report.used_count).to eq(2)
        expect(report.unused_count).to eq(2)
        expect(report.coverage_percentage).to eq(50.0)
        expect(report.entry_types).to eq(["ns:TypeA", "ns:TypeB"])
      end
    end

    context "with dependencies" do
      before do
        # TypeA depends on TypeB
        allow(dependency_grapher).to receive(:extract_type_references)
          .with(anything) do |definition|
          if definition.name == "TypeA"
            ["ns:TypeB"]
          else
            []
          end
        end
      end

      it "includes dependent types in used types" do
        report = analyzer.analyze(entry_types: ["ns:TypeA"])

        expect(report.used_count).to eq(2) # TypeA + TypeB
        expect(report.coverage_percentage).to eq(50.0)
      end
    end

    context "with namespace analysis" do
      it "calculates coverage per namespace" do
        report = analyzer.analyze(entry_types: ["ns:TypeA", "other:TypeD"])

        by_ns = report.by_namespace

        expect(by_ns).to have_key("http://example.com/ns")
        expect(by_ns).to have_key("http://other.com/ns")

        # http://example.com/ns has 3 types, 1 used
        expect(by_ns["http://example.com/ns"][:total]).to eq(3)
        expect(by_ns["http://example.com/ns"][:used]).to eq(1)
        expect(by_ns["http://example.com/ns"][:coverage_percentage]).to eq(33.33)

        # http://other.com/ns has 1 type, 1 used
        expect(by_ns["http://other.com/ns"][:total]).to eq(1)
        expect(by_ns["http://other.com/ns"][:used]).to eq(1)
        expect(by_ns["http://other.com/ns"][:coverage_percentage]).to eq(100.0)
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::CoverageReport do
  let(:all_types) { Set.new(["{ns}TypeA", "{ns}TypeB", "{ns}TypeC"]) }
  let(:used_types) { Set.new(["{ns}TypeA", "{ns}TypeB"]) }
  let(:entry_types) { ["TypeA"] }
  let(:by_namespace) do
    {
      "http://example.com/ns" => {
        total: 3,
        used: 2,
        types: [
          { clark_key: "{ns}TypeA", name: "TypeA", category: :complex_type,
            used: true },
          { clark_key: "{ns}TypeB", name: "TypeB", category: :complex_type,
            used: true },
          { clark_key: "{ns}TypeC", name: "TypeC", category: :simple_type,
            used: false },
        ],
        coverage_percentage: 66.67,
      },
    }
  end

  let(:report) do
    described_class.new(
      all_types: all_types,
      used_types: used_types,
      entry_types: entry_types,
      by_namespace: by_namespace,
    )
  end

  describe "#total_types" do
    it "returns total number of types" do
      expect(report.total_types).to eq(3)
    end
  end

  describe "#used_count" do
    it "returns number of used types" do
      expect(report.used_count).to eq(2)
    end
  end

  describe "#unused_types" do
    it "returns set of unused types" do
      expect(report.unused_types).to eq(Set.new(["{ns}TypeC"]))
    end

    it "is mutually exclusive with used_types" do
      expect(report.unused_types & report.used_types).to be_empty
    end

    it "is collectively exhaustive with used_types" do
      expect(report.unused_types | report.used_types).to eq(all_types)
    end
  end

  describe "#unused_count" do
    it "returns number of unused types" do
      expect(report.unused_count).to eq(1)
    end
  end

  describe "#coverage_percentage" do
    it "calculates coverage percentage" do
      expect(report.coverage_percentage).to eq(66.67)
    end

    context "with no types" do
      let(:all_types) { Set.new }
      let(:used_types) { Set.new }

      it "returns 0.0 for empty repository" do
        expect(report.coverage_percentage).to eq(0.0)
      end
    end

    context "with 100% coverage" do
      let(:used_types) { all_types }

      it "returns 100.0" do
        expect(report.coverage_percentage).to eq(100.0)
      end
    end
  end

  describe "#to_h" do
    it "converts to hash with summary" do
      hash = report.to_h

      expect(hash).to have_key(:summary)
      expect(hash[:summary]).to include(
        total_types: 3,
        used_types: 2,
        unused_types: 1,
        coverage_percentage: 66.67,
        entry_types: ["TypeA"],
      )
    end

    it "includes namespace data" do
      hash = report.to_h

      expect(hash).to have_key(:by_namespace)
      expect(hash[:by_namespace]).to have_key("http://example.com/ns")

      ns_data = hash[:by_namespace]["http://example.com/ns"]
      expect(ns_data).to include(
        total: 3,
        used: 2,
        unused: 1,
        coverage_percentage: 66.67,
      )
    end

    it "includes unused type details" do
      hash = report.to_h

      expect(hash).to have_key(:unused_type_details)
      expect(hash[:unused_type_details]).to be_an(Array)
      expect(hash[:unused_type_details].size).to eq(1)

      unused = hash[:unused_type_details].first
      expect(unused).to include(
        namespace: "http://example.com/ns",
        name: "TypeC",
        category: :simple_type,
        clark_key: "{ns}TypeC",
      )
    end

    it "sorts unused types by namespace and name" do
      # Test with multiple unused types
      extended_by_namespace = {
        "http://example.com/ns" => {
          total: 3,
          used: 1,
          types: [
            { clark_key: "{ns}TypeA", name: "TypeA", category: :complex_type,
              used: true },
            { clark_key: "{ns}TypeC", name: "TypeC", category: :simple_type,
              used: false },
            { clark_key: "{ns}TypeB", name: "TypeB", category: :simple_type,
              used: false },
          ],
          coverage_percentage: 33.33,
        },
      }

      extended_report = described_class.new(
        all_types: all_types,
        used_types: Set.new(["{ns}TypeA"]),
        entry_types: entry_types,
        by_namespace: extended_by_namespace,
      )

      hash = extended_report.to_h
      names = hash[:unused_type_details].map { |t| t[:name] }

      expect(names).to eq(%w[TypeB TypeC]) # Sorted alphabetically
    end
  end

  describe "MECE principle" do
    it "ensures used and unused types are mutually exclusive" do
      # No overlap between used and unused
      intersection = report.used_types & report.unused_types
      expect(intersection).to be_empty
    end

    it "ensures used and unused types are collectively exhaustive" do
      # Union equals all types
      union = report.used_types | report.unused_types
      expect(union).to eq(report.all_types)
    end

    it "validates counts add up correctly" do
      expect(report.used_count + report.unused_count).to eq(report.total_types)
    end
  end
end
