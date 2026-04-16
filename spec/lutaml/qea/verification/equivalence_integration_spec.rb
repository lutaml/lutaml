# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/verification/document_verifier"

RSpec.describe "XMI/QEA Equivalence Integration" do
  let(:verifier) { Lutaml::Qea::Verification::DocumentVerifier.new }
  let(:examples_dir) { File.join(__dir__, "../../../../examples/qea") }

  shared_examples "equivalent documents" do |xmi_file, qea_file, description|
    describe description do
      let(:xmi_path) { File.join(examples_dir, xmi_file) }
      let(:qea_path) { File.join(examples_dir, qea_file) }
      let(:result) { verifier.verify(xmi_path, qea_path) }

      before do
        unless File.exist?(xmi_path) && File.exist?(qea_path)
          skip "Files not found"
        end
      end

      it "has same or more packages" do
        xmi_only = result.xmi_only[:packages]
        expect(xmi_only).to be_empty,
                            "QEA missing packages: #{xmi_only.join(', ')}"
      end

      it "has same or more classes" do
        xmi_only = result.xmi_only[:classes]
        expect(xmi_only).to be_empty,
                            "QEA missing classes: #{xmi_only.join(', ')}"
      end

      it "preserves all XMI class names" do
        xmi_only_classes = result.xmi_only[:classes]
        expect(xmi_only_classes).to be_empty,
                                    "Missing classes in QEA: #{xmi_only_classes.first(10).join(', ')}"
      end

      it "preserves class properties" do
        critical_diffs = result.property_differences.select do |diff|
          diff[:differences].any? { |d| d.include?("QEA has fewer") }
        end

        expect(critical_diffs).to be_empty,
                                  "Property differences found: #{critical_diffs.map do |d|
                                    d[:name]
                                  end.join(', ')}"
      end

      it "does not lose critical information" do
        critical_issues = result.critical_issues
        expect(critical_issues).to be_empty,
                                   "Critical issues: #{critical_issues.join('; ')}"
      end

      it "is equivalent (QEA >= XMI)" do
        expect(result.equivalent?).to be(true),
                                      "Documents not equivalent:\n#{result.summary}"
      end

      it "has reasonable statistics" do
        stats = result.statistics
        expect(stats[:total_matches]).to be > 0
      end
    end
  end

  # Test all 4 file pairs
  it_behaves_like "equivalent documents",
                  "UmlModel_template.xmi",
                  "UmlModel_template.qea",
                  "UmlModel_template"

  it_behaves_like "equivalent documents",
                  "test.xmi",
                  "test.qea",
                  "test"

  it_behaves_like "equivalent documents",
                  "ArcGISWorkspace_template.xmi",
                  "ArcGISWorkspace_template.qea",
                  "ArcGISWorkspace_template"

  it_behaves_like "equivalent documents",
                  "20251010_current_plateau_v5.1.xmi",
                  "20251010_current_plateau_v5.1.qea",
                  "20251010_current_plateau_v5.1"

  describe "detailed verification" do
    let(:xmi_path) { File.join(examples_dir, "test.xmi") }
    let(:qea_path) { File.join(examples_dir, "test.qea") }
    let(:result) { verifier.verify(xmi_path, qea_path) }

    before do
      unless File.exist?(xmi_path) && File.exist?(qea_path)
        skip "Files not found"
      end
    end

    it "generates a detailed summary" do
      summary = result.summary
      expect(summary).to include("Verification Summary")
      expect(summary).to include("Matched Elements")
    end

    it "generates a detailed report" do
      report = result.to_report
      expect(report).to have_key(:equivalent)
      expect(report).to have_key(:matches)
      expect(report).to have_key(:xmi_only)
      expect(report).to have_key(:qea_only)
      expect(report).to have_key(:property_differences)
      expect(report).to have_key(:summary)
    end

    it "identifies acceptable differences" do
      acceptable = result.acceptable_differences
      # QEA may have more elements - this is acceptable
      expect(acceptable).to be_an(Array)
      if acceptable.any?

      end
    end
  end

  describe "normalizer" do
    let(:normalizer) { Lutaml::Qea::Verification::DocumentNormalizer.new }
    let(:xmi_path) { File.join(examples_dir, "test.xmi") }
    let(:xmi_doc) { Lutaml::Xmi::Parsers::Xml.parse(File.read(xmi_path)) }

    before do
      skip "File not found" unless File.exist?(xmi_path)
    end

    it "removes XMI IDs" do
      normalized = normalizer.normalize(xmi_doc)

      # Check that associations don't have XMI IDs
      normalized.associations&.each do |assoc|
        expect(assoc.owner_end_xmi_id).to be_nil
        expect(assoc.member_end_xmi_id).to be_nil
      end
    end

    it "sorts collections" do
      normalized = normalizer.normalize(xmi_doc)

      # Check packages are sorted
      if normalized.packages && normalized.packages.size > 1
        names = normalized.packages.filter_map(&:name)
        expect(names).to eq(names.sort)
      end

      # Check classes are sorted
      if normalized.classes && normalized.classes.size > 1
        names = normalized.classes.filter_map(&:name)
        expect(names).to eq(names.sort)
      end
    end
  end

  describe "structure matcher" do
    let(:matcher) { Lutaml::Qea::Verification::StructureMatcher.new }
    let(:xmi_path) { File.join(examples_dir, "test.xmi") }
    let(:qea_path) { File.join(examples_dir, "test.qea") }
    let(:xmi_doc) { Lutaml::Parser.parse([File.new(xmi_path)]).first }
    let(:qea_doc) { Lutaml::Qea.parse(qea_path) }

    before do
      unless File.exist?(xmi_path) && File.exist?(qea_path)
        skip "Files not found"
      end
    end

    it "matches packages correctly" do
      result = matcher.match_packages(xmi_doc, qea_doc)
      expect(result).to have_key(:matches)
      expect(result).to have_key(:xmi_only)
      expect(result).to have_key(:qea_only)
      expect(result[:matches]).to be_a(Hash)
    end

    it "matches classes correctly" do
      result = matcher.match_classes(xmi_doc, qea_doc)
      expect(result).to have_key(:matches)
      expect(result).to have_key(:xmi_only)
      expect(result).to have_key(:qea_only)
      expect(result[:matches]).to be_a(Hash)
    end

    it "builds qualified names" do
      qualified_names = matcher.build_qualified_names(xmi_doc)
      expect(qualified_names).to have_key(:packages)
      expect(qualified_names).to have_key(:classes)
      expect(qualified_names).to have_key(:enums)
      expect(qualified_names).to have_key(:data_types)
    end
  end

  describe "element comparator" do
    let(:comparator) { Lutaml::Qea::Verification::ElementComparator.new }

    it "compares packages" do
      pkg1 = Lutaml::Uml::Package.new(name: "TestPackage")
      pkg2 = Lutaml::Uml::Package.new(name: "TestPackage")

      result = comparator.compare_packages(pkg1, pkg2)
      expect(result[:equal]).to be(true)
      expect(result[:differences]).to be_empty
    end

    it "detects package differences" do
      pkg1 = Lutaml::Uml::Package.new(name: "Package1")
      pkg2 = Lutaml::Uml::Package.new(name: "Package2")

      result = comparator.compare_packages(pkg1, pkg2)
      expect(result[:equal]).to be(false)
      expect(result[:differences]).not_to be_empty
    end

    it "compares classes" do
      klass1 = Lutaml::Uml::Class.new(name: "TestClass", is_abstract: false)
      klass2 = Lutaml::Uml::Class.new(name: "TestClass", is_abstract: false)

      result = comparator.compare_classes(klass1, klass2)
      expect(result[:equal]).to be(true)
    end

    it "detects class differences" do
      klass1 = Lutaml::Uml::Class.new(name: "TestClass", is_abstract: false)
      klass2 = Lutaml::Uml::Class.new(name: "TestClass", is_abstract: true)

      result = comparator.compare_classes(klass1, klass2)
      expect(result[:equal]).to be(false)
      expect(result[:differences]).to include(a_string_including("is_abstract"))
    end
  end

  describe "comparison result" do
    let(:result) { Lutaml::Qea::Verification::ComparisonResult.new }

    it "starts with no matches" do
      expect(result.matches.values.sum).to eq(0)
    end

    it "records matches" do
      result.add_matches(:packages, 10)
      result.add_matches(:classes, 20)

      expect(result.matches[:packages]).to eq(10)
      expect(result.matches[:classes]).to eq(20)
    end

    it "records XMI-only elements" do
      result.add_xmi_only(:classes, ["Class1", "Class2"])
      expect(result.xmi_only[:classes]).to eq(["Class1", "Class2"])
    end

    it "records QEA-only elements" do
      result.add_qea_only(:classes, ["Class3", "Class4"])
      expect(result.qea_only[:classes]).to eq(["Class3", "Class4"])
    end

    it "is equivalent when no critical issues" do
      result.add_matches(:classes, 10)
      result.add_qea_only(:classes, ["ExtraClass"])
      expect(result.equivalent?).to be(true)
    end

    it "is not equivalent when XMI elements missing" do
      result.add_xmi_only(:classes, ["MissingClass"])
      expect(result.equivalent?).to be(false)
    end

    it "generates statistics" do
      result.add_matches(:classes, 5)
      result.add_xmi_only(:packages, ["Pkg1"])
      result.add_qea_only(:classes, ["Class1", "Class2"])

      stats = result.statistics
      expect(stats[:total_matches]).to eq(5)
      expect(stats[:total_xmi_only]).to eq(1)
      expect(stats[:total_qea_only]).to eq(2)
    end

    it "identifies critical issues" do
      result.add_xmi_only(:classes, ["MissingClass"])
      result.add_property_difference(:class, "TestClass",
                                     ["attributes: 5 (XMI) vs 3 (QEA) - QEA has fewer"])

      issues = result.critical_issues
      expect(issues).not_to be_empty
      expect(issues.join).to include("Missing")
    end

    it "identifies acceptable differences" do
      result.add_qea_only(:classes, ["ExtraClass"])
      result.add_property_difference(:class, "TestClass",
                                     ["attributes: 3 (XMI) vs 5 (QEA) - QEA has more (acceptable)"])

      acceptable = result.acceptable_differences
      expect(acceptable).not_to be_empty
      expect(acceptable.join).to include("additional")
    end
  end
end
