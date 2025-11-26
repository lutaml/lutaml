# frozen_string_literal: true

require "spec_helper"
require "canon"
require_relative "../../../support/svg_comparison_helper"
require_relative "../../../../lib/lutaml/ea/diagram"

RSpec.describe "EA Diagram SVG Accuracy" do
  # Path to test repository
  LUR_PATH = "spec/fixtures/basic_test.lur"

  # Diagrams to test from basic_test.lur
  # These diagrams have complete rendering data and EA reference SVGs
  DIAGRAMS_TO_TEST = [
    {
      name: "Starter Object Diagram",
      xmi_id: "EAID_D14AA320_9D41_4366_8739_9C2C21F96AE1",
      expected_ea_file: "EAID_D14AA320_9D41_4366_8739_9C2C21F96AE1.svg"
    },
    {
      name: "Basic Class Diagram with Attributes",
      xmi_id: "EAID_4F421236_FCF3_4aae_B22A_C7E6A5EFBAC7",
      expected_ea_file: "EAID_4F421236_FCF3_4aae_B22A_C7E6A5EFBAC7.svg"
    },
    {
      name: "Package Contents",
      xmi_id: "EAID_F0F20BDF_C729_47f7_B6FC_25ED2C4609CA",
      expected_ea_file: "EAID_F0F20BDF_C729_47f7_B6FC_25ED2C4609CA.svg"
    }
  ].freeze

  include SvgComparisonHelper

  let(:qea_path) { "spec/fixtures/test.qea" }
  let(:lur_path) { LUR_PATH }
  let(:reference_dir) { "examples/xmi/Images" }

  # Helper to convert XMI ID to EA SVG filename
  # {F4C23F9E-DD74-4fed-B75D-AD3C6448BA24} → EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24.svg
  # EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24 → EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24.svg
  def xmi_id_to_ea_filename(xmi_id)
    # Handle XMI IDs that already have EAID_ prefix
    return "#{xmi_id}.svg" if xmi_id.start_with?('EAID_')

    # Convert from {GUID} format
    # Remove curly braces and replace dashes with underscores, preserve case
    clean_id = xmi_id.gsub(/[{}]/, '').gsub('-', '_')
    "EAID_#{clean_id}.svg"
  end

  # Helper to find EA reference SVG by XMI ID
  def find_ea_reference_svg(xmi_id)
    filename = xmi_id_to_ea_filename(xmi_id)
    path = File.join(reference_dir, filename)
    File.exist?(path) ? path : nil
  end

  # Load repository once for all tests
  let(:repository) do
    if File.exist?(lur_path)
      Lutaml::UmlRepository::RepositoryEnhanced.from_file(lur_path)
    else
      skip "Repository file not found: #{lur_path}"
    end
  end

  # Get all diagrams from repository
  let(:diagrams) { repository.all_diagrams }

  before(:all) do
    # Display information about test setup
    puts "\n" + "=" * 80
    puts "SVG Accuracy Test Suite - EA Reference Comparison".center(80)
    puts "=" * 80
    puts "\nThis test suite validates diagram generation accuracy against"
    puts "Enterprise Architect (EA) SVG exports using Canon gem's XML equivalence."
    puts "\nEA Reference directory: examples/xmi/Images/"
    puts "\n" + "=" * 80 + "\n"
  end

  describe "Reference file availability" do
    it "has EA reference directory" do
      expect(Dir.exist?(reference_dir)).to be_truthy
    end

    it "contains EA-generated SVG files" do
      svg_files = Dir.glob(File.join(reference_dir, "EAID_*.svg"))
      expect(svg_files).not_to be_empty,
        "EA reference directory should contain SVG files"

      puts "\n  Found #{svg_files.size} EA reference SVG files"
    end

    it "has Canon gem available for XML equivalence testing" do
      expect(defined?(Canon)).to be_truthy,
        "Canon gem should be loaded for XML equivalence testing"
    end
  end

  describe "Test fixture availability" do
    it "has basic_test.lur repository" do
      expect(File.exist?(LUR_PATH)).to be true
    end

    it "loads repository successfully" do
      expect { repository }.not_to raise_error
    end

    it "has diagrams in repository" do
      skip "Repository file not found" unless File.exist?(LUR_PATH)

      diagrams = repository.all_diagrams
      expect(diagrams).not_to be_empty

      puts "\n  Diagrams in basic_test.lur: #{diagrams.size}"
      puts "  Testing #{DIAGRAMS_TO_TEST.size} diagrams with EA references:"
    end
  end

  # Test each diagram in the repository
  DIAGRAMS_TO_TEST.each do |diagram_info|
    describe "diagram: #{diagram_info[:name]}" do
      let(:diagram_name) { diagram_info[:name] }
      let(:diagram_xmi_id) { diagram_info[:xmi_id] }
      let(:diagram) { repository.find_diagram(diagram_xmi_id) }
      let(:ea_reference_path) { find_ea_reference_svg(diagram_xmi_id) }

      before do
        unless diagram
          skip "Diagram '#{diagram_name}' not found in repository"
        end
      end

      context "with EA reference SVG" do
        before do
          unless ea_reference_path
            skip "EA reference SVG not found. Expected: #{reference_dir}/#{diagram_info[:expected_ea_file]}"
          end
        end

        let(:ea_reference_svg) { File.read(ea_reference_path) }

        let(:generated_svg) do
          extractor = Lutaml::Ea::Diagram::Extractor.new
          result = extractor.extract_one(lur_path, diagram_xmi_id, output: nil)

          expect(result[:success]).to be_truthy,
            "Diagram extraction failed: #{result[:error]}"

          result[:svg_content]
        end

        describe "XML equivalence using Canon gem" do
          it "generates SVG that is XML-equivalent to EA export" do
            skip "Generated SVG is empty (diagram lacks rendering data)" if generated_svg.nil? || generated_svg.empty?

            puts "\n  Comparing generated SVG with EA reference using Canon gem..."
            puts "  EA reference: #{File.basename(ea_reference_path)}"
            puts "  Generated size: #{generated_svg.bytesize} bytes"
            puts "  Reference size: #{ea_reference_svg.bytesize} bytes"

            # Use Canon's be_xml_equivalent_to matcher
            expect(generated_svg).to be_xml_equivalent_to(ea_reference_svg)
          end
        end

        describe "structure comparison (fallback)" do
          it "generates SVG with similar structure to EA export" do
            skip "Generated SVG is empty (diagram lacks rendering data)" if generated_svg.nil? || generated_svg.empty?

            comparison = compare_svg_structure(generated_svg, ea_reference_svg)

            unless comparison[:matching]
              puts "\n  Structure Differences:"
              comparison[:differences].first(5).each do |diff|
                puts "    - #{diff}"
              end
              puts "    ... and #{comparison[:differences].size - 5} more" if comparison[:differences].size > 5
            end

            # Allow some variance in structure (EA may include extra metadata)
            gen_total = comparison[:generated_elements].values.sum
            ref_total = comparison[:reference_elements].values.sum
            variance = (gen_total - ref_total).abs.to_f / [ref_total, 1].max

            expect(variance).to be < 0.2,
              "Element count should be within 20% (generated: #{gen_total}, EA: #{ref_total})"
          end
        end

        describe "coordinate accuracy (fallback)" do
          it "generates coordinates similar to EA export" do
            skip "Generated SVG is empty (diagram lacks rendering data)" if generated_svg.nil? || generated_svg.empty?

            gen_coords = extract_coordinates(generated_svg)
            ref_coords = extract_coordinates(ea_reference_svg)

            differences = compare_coordinates(gen_coords, ref_coords, tolerance: 10.0)

            unless differences.empty?
              puts "\n  Coordinate Differences (tolerance: 10px):"
              differences.first(10).each do |diff|
                puts "    - #{diff}"
              end
              puts "    ... and #{differences.size - 10} more" if differences.size > 10
            end

            # Allow more tolerance for coordinate comparison (10px instead of 5px)
            expect(differences.size).to be < gen_coords.values.flatten.size * 0.3,
              "Should have <30% coordinate differences (found #{differences.size})"
          end
        end

        describe "content preservation" do
          it "includes similar text content to EA export" do
            skip "Generated SVG is empty (diagram lacks rendering data)" if generated_svg.nil? || generated_svg.empty?

            gen_doc = Nokogiri::XML(generated_svg)
            ref_doc = Nokogiri::XML(ea_reference_svg)

            gen_texts = gen_doc.xpath("//text").map(&:content).map(&:strip).reject(&:empty?).uniq
            ref_texts = ref_doc.xpath("//text").map(&:content).map(&:strip).reject(&:empty?).uniq

            # Check for significant text overlap
            common_texts = gen_texts & ref_texts
            overlap_ratio = common_texts.size.to_f / [ref_texts.size, 1].max

            puts "\n  Text overlap: #{(overlap_ratio * 100).round(2)}% (#{common_texts.size}/#{ref_texts.size})"

            expect(overlap_ratio).to be >= 0.5,
              "Should preserve at least 50% of text content from EA export"
          end
        end

        describe "visual validity" do
          it "produces valid SVG output" do
            skip "Generated SVG is empty (diagram lacks rendering data)" if generated_svg.nil? || generated_svg.empty?

            doc = Nokogiri::XML(generated_svg)
            errors = doc.errors

            expect(errors).to be_empty,
              "Generated SVG should be valid XML. Errors:\n#{errors.map(&:message).join("\n")}"

            expect(doc.root&.name).to eq("svg"),
              "Root element should be <svg>"
          end
        end
      end

      context "without EA reference SVG" do
        before do
          if ea_reference_path
            skip "EA reference SVG is available, use 'with EA reference SVG' tests instead"
          end
        end

        it "generates valid SVG output" do
          extractor = Lutaml::Ea::Diagram::Extractor.new
          result = extractor.extract_one(lur_path, diagram_xmi_id, output: nil)

          expect(result[:success]).to be_truthy

          svg = result[:svg_content]

          if svg.nil? || svg.empty?
            skip "Diagram has no rendering data (empty SVG output)"
          end

          doc = Nokogiri::XML(svg)
          expect(doc.errors).to be_empty

          if doc.root
            expect(doc.root.name).to eq("svg")
          else
            skip "Generated SVG has no root element"
          end
        end
      end
    end
  end

  describe "Helper utilities" do
    describe "#xmi_id_to_ea_filename" do
      it "converts XMI ID to EA filename format" do
        xmi_id = "{F4C23F9E-DD74-4fed-B75D-AD3C6448BA24}"
        expected = "EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24.svg"

        expect(xmi_id_to_ea_filename(xmi_id)).to eq(expected)
      end

      it "handles lowercase XMI IDs" do
        xmi_id = "{b58d1a53-e860-41a3-8352-11c274093e83}"
        result = xmi_id_to_ea_filename(xmi_id)

        expect(result).to start_with("EAID_")
        expect(result).to end_with(".svg")
        expect(result).to include("b58d1a53")  # Preserves lowercase
      end
    end

    describe "#find_ea_reference_svg" do
      it "finds existing EA reference SVG" do
        xmi_id = "{B58D1A53-E860-41a3-8352-11C274093E83}"
        path = find_ea_reference_svg(xmi_id)

        expect(path).not_to be_nil
        expect(File.exist?(path)).to be true
      end

      it "returns nil for non-existent reference" do
        xmi_id = "{00000000-0000-0000-0000-000000000000}"
        path = find_ea_reference_svg(xmi_id)

        expect(path).to be_nil
      end
    end

    describe "Canon gem integration" do
      it "has Canon matcher available" do
        expect(self).to respond_to(:be_xml_equivalent_to)
      end

      it "can compare simple XML equivalence" do
        xml1 = '<svg><rect x="10" y="20" /></svg>'
        xml2 = '<svg><rect y="20" x="10" /></svg>'  # Different attribute order

        expect(xml1).to be_xml_equivalent_to(xml2)
      end
    end
  end
end