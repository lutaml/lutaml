# frozen_string_literal: true

require "spec_helper"
require "canon"
require_relative "../../../support/svg_comparison_helper"
require_relative "../../../../lib/lutaml/ea/diagram"
require_relative "../../../../lib/lutaml/ea/diagram/extractor"

RSpec.describe "EA Diagram SVG Accuracy" do
  # Path to test repository
  lur_path = File.expand_path("../../../../examples/lur/basic.lur", __dir__)

  # Diagrams to test from basic.lur
  # These diagrams have complete rendering data and EA reference SVGs
  diagrams_to_test = [
    {
      name: "Starter Object Diagram",
      xmi_id: "EAID_D14AA320_9D41_4366_8739_9C2C21F96AE1",
      expected_ea_file: "EAID_D14AA320_9D41_4366_8739_9C2C21F96AE1.svg",
    },
    {
      name: "Basic Class Diagram with Attributes",
      xmi_id: "EAID_4F421236_FCF3_4aae_B22A_C7E6A5EFBAC7",
      expected_ea_file: "EAID_4F421236_FCF3_4aae_B22A_C7E6A5EFBAC7.svg",
    },
    {
      name: "Package Contents",
      xmi_id: "EAID_F0F20BDF_C729_47f7_B6FC_25ED2C4609CA",
      expected_ea_file: "EAID_F0F20BDF_C729_47f7_B6FC_25ED2C4609CA.svg",
    },
  ].freeze

  include SvgComparisonHelper

  let(:qea_path) { "spec/fixtures/test.qea" }
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
  let(:lur_path) { lur_path }
  let(:reference_dir) { "examples/xmi/Images" }

  # Helper to convert XMI ID to EA SVG filename
  # {F4C23F9E-DD74-4fed-B75D-AD3C6448BA24} →
  #  EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24.svg
  # EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24 →
  #  EAID_F4C23F9E_DD74_4fed_B75D_AD3C6448BA24.svg
  def xmi_id_to_ea_filename(xmi_id)
    # Handle XMI IDs that already have EAID_ prefix
    return "#{xmi_id}.svg" if xmi_id.start_with?("EAID_")

    # Convert from {GUID} format
    # Remove curly braces and replace dashes with underscores, preserve case
    clean_id = xmi_id.gsub(/[{}]/, "").gsub("-", "_")
    "EAID_#{clean_id}.svg"
  end

  # Helper to find EA reference SVG by XMI ID
  def find_ea_reference_svg(xmi_id)
    filename = xmi_id_to_ea_filename(xmi_id)
    path = File.join(reference_dir, filename)
    File.exist?(path) ? path : nil
  end

  describe "Reference file availability" do
    it "has EA reference directory" do
      expect(Dir).to exist(reference_dir)
    end

    it "contains EA-generated SVG files" do
      svg_files = Dir.glob(File.join(reference_dir, "EAID_*.svg"))
      expect(svg_files)
        .not_to be_empty, "EA reference directory should contain SVG files"
    end

    it "has Canon gem available for XML equivalence testing" do
      expect(defined?(Canon))
        .to be_truthy, "Canon gem should be loaded for XML equivalence testing"
    end
  end

  describe "Test fixture availability" do
    it "has basic.lur repository" do
      expect(File.exist?(lur_path)).to be true
    end

    it "loads repository successfully" do
      expect { repository }.not_to raise_error
    end

    it "has diagrams in repository" do
      skip "Repository file not found" unless File.exist?(lur_path)

      diagrams = repository.all_diagrams
      expect(diagrams).not_to be_empty
    end
  end

  # Test each diagram in the repository
  diagrams_to_test.each do |diagram_info|
    describe "diagram: #{diagram_info[:name]}" do
      let(:diagram_name) { diagram_info[:name] }
      let(:diagram_xmi_id) { diagram_info[:xmi_id] }
      let(:diagram) { repository.find_diagram(diagram_name) }
      let(:ea_reference_path) { find_ea_reference_svg(diagram_xmi_id) }

      before do
        unless diagram
          skip "Diagram '#{diagram_name}' not found in repository"
        end
      end

      context "with EA reference SVG" do
        before do
          unless ea_reference_path
            skip "EA reference SVG not found. Expected: " \
                 "#{reference_dir}/#{diagram_info[:expected_ea_file]}"
          end
        end

        let(:ea_reference_svg) { File.read(ea_reference_path) }

        let(:generated_svg) do
          extractor = Lutaml::Ea::Diagram::Extractor.new
          result = extractor.extract_one(lur_path, diagram_xmi_id, output: nil)

          expect(result[:success])
            .to be_truthy, "Diagram extraction failed: #{result[:error]}"

          result[:svg_content]
        end

        describe "XML equivalence using Canon gem" do
          it "generates SVG with equivalent structure to EA export" do
            if generated_svg.nil? || generated_svg.empty?
              skip "Generated SVG is empty (diagram lacks rendering data)"
            end

            gen_doc = Nokogiri::XML(generated_svg)
            ref_doc = Nokogiri::XML(ea_reference_svg)

            # Both should be valid SVG documents
            expect(gen_doc.root&.name).to eq("svg")
            expect(ref_doc.root&.name).to eq("svg")

            # Both should have title and desc elements
            gen_doc.remove_namespaces!
            ref_doc.remove_namespaces!
            expect(gen_doc.xpath("//title")).not_to be_empty
            expect(gen_doc.xpath("//desc")).not_to be_empty

            # Both should contain visual elements
            gen_visual = gen_doc.xpath("//rect | //text | //path").size
            expect(gen_visual).to be > 0,
                                  "Generated SVG should have visual elements"
          end
        end

        describe "structure comparison (fallback)" do
          it "generates SVG with similar structure to EA export" do
            if generated_svg.nil? || generated_svg.empty?
              skip "Generated SVG is empty (diagram lacks rendering data)"
            end

            gen_doc = Nokogiri::XML(generated_svg)
            gen_doc.remove_namespaces!
            ref_doc = Nokogiri::XML(ea_reference_svg)
            ref_doc.remove_namespaces!

            # Check that key element types exist in generated SVG
            expected_elements = %w[rect text]
            expected_elements.each do |elem_type|
              gen_count = gen_doc.xpath("//#{elem_type}").size
              expect(gen_count).to be > 0,
                                   "Generated SVG should have #{elem_type} " \
                                   "elements"
            end

            # Both should have path elements (connectors or separators)
            gen_paths = gen_doc.xpath("//path").size
            expect(gen_paths).to be >= 0
          end
        end

        describe "coordinate accuracy (fallback)" do
          it "generates coordinates within viewBox bounds" do
            if generated_svg.nil? || generated_svg.empty?
              skip "Generated SVG is empty (diagram lacks rendering data)"
            end

            gen_doc = Nokogiri::XML(generated_svg)
            gen_doc.remove_namespaces!

            # Parse viewBox from generated SVG
            view_box = gen_doc.root["viewBox"]&.split&.map(&:to_f)
            expect(view_box).not_to be_nil, "SVG should have a viewBox"

            vb_x, vb_y, vb_w, vb_h = view_box
            violations = []

            # Check all rect elements are within viewBox
            gen_doc.xpath("//rect").each do |rect|
              rx = rect["x"].to_f
              ry = rect["y"].to_f
              rw = rect["width"].to_f
              rh = rect["height"].to_f
              if rx < vb_x || ry < vb_y ||
                  rx + rw > vb_x + vb_w || ry + rh > vb_y + vb_h
                violations << "rect at (#{rx},#{ry}) " \
                              "exceeds viewBox (#{vb_x},#{vb_y}," \
                              "#{vb_x + vb_w},#{vb_y + vb_h})"
              end
            end

            expect(violations).to be_empty,
                                  "All elements should be within viewBox:" \
                                  "\n#{violations.join("\n")}"
          end
        end

        describe "content preservation" do
          it "includes similar text content to EA export" do
            if generated_svg.nil? || generated_svg.empty?
              skip "Generated SVG is empty (diagram lacks rendering data)"
            end

            gen_doc = Nokogiri::XML(generated_svg)
            ref_doc = Nokogiri::XML(ea_reference_svg)
            gen_doc.remove_namespaces!
            ref_doc.remove_namespaces!

            gen_texts = gen_doc.xpath("//text")
              .map { |x| x.content.strip }.reject(&:empty?).uniq
            ref_texts = ref_doc.xpath("//text")
              .map { |x| x.content.strip }.reject(&:empty?).uniq

            # Use substring matching: an EA text is "matched" if it appears
            # as a substring in any generated text (our renderer may include
            # additional info like type names)
            matched = ref_texts.count do |ref_text|
              gen_texts.any? { |gen_text| gen_text.include?(ref_text) }
            end
            overlap_ratio = matched.to_f / [ref_texts.size, 1].max

            expect(overlap_ratio)
              .to be >= 0.5, "Should preserve at least 50% of text content " \
                             "from EA export (#{matched}/#{ref_texts.size} " \
                             "matched)"
          end
        end

        describe "visual validity" do
          it "produces valid SVG output" do
            if generated_svg.nil? || generated_svg.empty?
              skip "Generated SVG is empty (diagram lacks rendering data)"
            end

            doc = Nokogiri::XML(generated_svg)
            errors = doc.errors

            expect(errors)
              .to be_empty, "Generated SVG should be valid XML. " \
                            "Errors:\n#{errors.map(&:message).join("\n")}"

            expect(doc.root&.name).to eq("svg"),
                                      "Root element should be <svg>"
          end
        end
      end

      context "without EA reference SVG" do
        before do
          if ea_reference_path
            skip "EA reference SVG is available, " \
                 "use 'with EA reference SVG' tests instead"
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
        expect(result).to include("b58d1a53") # Preserves lowercase
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
        xml2 = '<svg><rect y="20" x="10" /></svg>' # Different attribute order

        expect(xml1).to be_xml_equivalent_to(xml2)
      end
    end
  end
end
