# frozen_string_literal: true

require "nokogiri"

# Helper module for comparing SVG files in diagram accuracy tests
#
# This module provides utilities to:
# - Normalize SVG content for comparison
# - Compare SVG structure and element counts
# - Extract and compare coordinates with tolerance
# - Calculate visual similarity metrics
#
# Usage:
#   RSpec.describe "SVG Accuracy" do
#     include SvgComparisonHelper
#
#     it "generates accurate SVG" do
#       generated = File.read("output.svg")
#       reference = File.read("reference.svg")
#       result = compare_svg_structure(generated, reference)
#       expect(result[:matching]).to be true
#     end
#   end
module SvgComparisonHelper
  # Acceptable differences that should be ignored during comparison
  EA_METADATA_XPATHS = [
    "//comment()",                    # XML comments
    "//*[@id]",                       # Element IDs (EA generates these)
    "//*[contains(@class, 'ea-')]", # EA-specific classes
    "//metadata",                     # Metadata elements
    "//defs/style",                   # Style definitions (may vary)
  ].freeze

  # Normalize SVG for comparison by removing EA-specific metadata
  # and standardizing formatting
  #
  # @param svg_string [String] Raw SVG content
  # @return [String] Normalized SVG string
  def normalize_svg(svg_string) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    return "" if svg_string.nil? || svg_string.empty?

    doc = Nokogiri::XML(svg_string)

    # Remove EA-specific metadata that varies between exports
    EA_METADATA_XPATHS.each do |xpath|
      doc.xpath(xpath).remove
    end

    # Remove generator meta tags
    doc.xpath('//meta[@name="generator"]').remove

    # Normalize whitespace in text elements
    doc.xpath("//text").each do |text_node|
      text_node.content = text_node.content.strip if text_node.content
    end

    # Standardize number formatting (remove trailing zeros)
    doc.xpath("//@*[string-length() > 0]").each do |attr|
      if /^-?\d+\.\d+$/.match?(attr.value)
        normalized = attr.value.to_f.round(2).to_s
        attr.value = normalized
      end
    end

    # Return formatted XML without declaration
    doc.to_xml(
      indent: 2,
      save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                 Nokogiri::XML::Node::SaveOptions::FORMAT,
    )
  end

  # Count elements by type in an SVG document
  #
  # @param svg_doc [Nokogiri::XML::Document] Parsed SVG document
  # @return [Hash] Element counts keyed by element name
  def count_elements(svg_doc)
    counts = Hash.new(0)

    svg_doc.xpath("//*").each do |elem|
      counts[elem.name] += 1
    end

    counts
  end

  # Compare SVG structure between generated and reference SVGs
  #
  # @param generated_svg [String] Generated SVG content
  # @param reference_svg [String] Reference SVG content
  # @return [Hash] Comparison result with :matching and :differences keys
  def compare_svg_structure(generated_svg, reference_svg)
    gen_doc = Nokogiri::XML(normalize_svg(generated_svg))
    ref_doc = Nokogiri::XML(normalize_svg(reference_svg))

    gen_elements = count_elements(gen_doc)
    ref_elements = count_elements(ref_doc)

    differences = calculate_element_differences(gen_elements, ref_elements)

    {
      matching: differences.empty?,
      generated_elements: gen_elements,
      reference_elements: ref_elements,
      differences: differences,
    }
  end

  # Calculate differences between element counts
  #
  # @param gen_elements [Hash] Generated element counts
  # @param ref_elements [Hash] Reference element counts
  # @return [Array<String>] List of difference descriptions
  def calculate_element_differences(gen_elements, ref_elements)
    differences = []

    # Check for missing elements
    ref_elements.each do |elem_type, ref_count|
      gen_count = gen_elements[elem_type] || 0
      if gen_count != ref_count
        differences << "#{elem_type}: count mismatch " \
                       "(generated: #{gen_count}, reference: #{ref_count})"
      end
    end

    # Check for extra elements
    gen_elements.each do |elem_type, gen_count|
      unless ref_elements.key?(elem_type)
        differences << "#{elem_type}: unexpected element (count: #{gen_count})"
      end
    end

    differences
  end

  # Extract coordinates from SVG elements
  #
  # @param svg_string [String] SVG content
  # @return [Hash] Coordinates grouped by element type
  def extract_coordinates(svg_string) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    doc = Nokogiri::XML(svg_string)
    coordinates = Hash.new { |h, k| h[k] = [] }

    # Extract from elements with x/y attributes
    doc.xpath("//*[@x and @y]").each do |elem|
      coordinates[elem.name] << {
        x: elem["x"].to_f,
        y: elem["y"].to_f,
        width: elem["width"]&.to_f,
        height: elem["height"]&.to_f,
      }
    end

    # Extract from rect elements
    doc.xpath("//rect").each do |elem|
      coordinates["rect"] << {
        x: elem["x"].to_f,
        y: elem["y"].to_f,
        width: elem["width"].to_f,
        height: elem["height"].to_f,
      }
    end

    # Extract from circle elements
    doc.xpath("//circle").each do |elem|
      coordinates["circle"] << {
        cx: elem["cx"].to_f,
        cy: elem["cy"].to_f,
        r: elem["r"].to_f,
      }
    end

    # Extract from line elements
    doc.xpath("//line").each do |elem|
      coordinates["line"] << {
        x1: elem["x1"].to_f,
        y1: elem["y1"].to_f,
        x2: elem["x2"].to_f,
        y2: elem["y2"].to_f,
      }
    end

    # Extract from path elements (just check existence, parsing is complex)
    doc.xpath("//path").each do |elem|
      coordinates["path"] << {
        d: elem["d"],
        length: elem["d"]&.length || 0,
      }
    end

    coordinates
  end

  # Compare coordinates between generated and reference SVGs
  #
  # @param gen_coords [Hash] Generated coordinates
  # @param ref_coords [Hash] Reference coordinates
  # @param tolerance [Float] Maximum acceptable difference in pixels
  # @return [Array<String>] List of coordinate differences
  def compare_coordinates(gen_coords, ref_coords, tolerance: 5.0) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    differences = []

    # Check each element type
    ref_coords.each do |element_type, ref_positions|
      gen_positions = gen_coords[element_type] || []

      # Check element count
      if gen_positions.size != ref_positions.size
        differences << "#{element_type}: count mismatch " \
                       "(generated: #{gen_positions.size}, " \
                       "reference: #{ref_positions.size})"
        next
      end

      # Compare each position
      ref_positions.each_with_index do |ref_pos, i|
        gen_pos = gen_positions[i]

        # Compare numeric coordinates
        ref_pos.each do |key, ref_value|
          next unless ref_value.is_a?(Numeric)

          gen_value = gen_pos[key]
          next unless gen_value.is_a?(Numeric)

          diff = (gen_value - ref_value).abs
          if diff > tolerance
            differences << "#{element_type}[#{i}].#{key}: off " \
                           "by #{diff.round(2)}px (tolerance: #{tolerance}px)"
          end
        end
      end
    end

    differences
  end

  # Calculate similarity score between two SVGs
  #
  # @param generated_svg [String] Generated SVG content
  # @param reference_svg [String] Reference SVG content
  # @return [Float] Similarity score (0.0 to 1.0)
  def calculate_similarity_score(generated_svg, reference_svg) # rubocop:disable Metrics/AbcSize
    structure_result = compare_svg_structure(generated_svg, reference_svg)

    # If structure doesn't match, score is based on element overlap
    return 0.0 if structure_result[:differences].size > 20

    gen_coords = extract_coordinates(generated_svg)
    ref_coords = extract_coordinates(reference_svg)

    coord_diffs = compare_coordinates(gen_coords, ref_coords, tolerance: 5.0)

    # Calculate score based on number of differences
    total_elements = structure_result[:reference_elements].values.sum
    return 0.0 if total_elements.zero?

    coord_errors = coord_diffs.size
    structure_errors = structure_result[:differences].size

    total_errors = coord_errors + structure_errors
    1.0 - [total_errors.to_f / total_elements, 1.0].min
  end

  # Check if visual comparison tools are available
  #
  # @return [Boolean] true if ImageMagick or rsvg-convert is available
  def visual_comparison_available?
    system("which convert > /dev/null 2>&1") ||
      system("which rsvg-convert > /dev/null 2>&1")
  end

  # Generate a visual diff between two SVG files (requires ImageMagick)
  #
  # @param generated_svg [String] Generated SVG content
  # @param reference_svg [String] Reference SVG content
  # @param output_path [String] Path to save diff image
  # @return [Hash] Result with :success and :similarity keys
  def visual_similarity(generated_svg, reference_svg, output_path: nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    unless visual_comparison_available?
      return {
        success: false,
        error: "Visual comparison tools not available",
        similarity: nil,
      }
    end

    require "tempfile"

    # Create temporary files
    Tempfile.create(["generated", ".svg"]) do |gen_file|
      Tempfile.create(["reference", ".svg"]) do |ref_file|
        gen_file.write(generated_svg)
        gen_file.close
        ref_file.write(reference_svg)
        ref_file.close

        # Convert to PNG and compare
        gen_png = "#{gen_file.path}.png"
        ref_png = "#{ref_file.path}.png"

        system("rsvg-convert #{gen_file.path} -o #{gen_png} 2>/dev/null") ||
          system("convert #{gen_file.path} #{gen_png} 2>/dev/null")

        system("rsvg-convert #{ref_file.path} -o #{ref_png} 2>/dev/null") ||
          system("convert #{ref_file.path} #{ref_png} 2>/dev/null")

        # Compare images
        if File.exist?(gen_png) && File.exist?(ref_png)
          diff_output = output_path || "#{gen_file.path}_diff.png"
          compare_result =
            `compare -metric AE #{gen_png} #{ref_png} #{diff_output} 2>&1`
          diff_pixels = compare_result.to_i

          # Calculate total pixels (approximate)
          identify_result = `identify -format "%w %h" #{ref_png} 2>&1`
          if identify_result =~ /(\d+) (\d+)/
            width = ::Regexp.last_match(1).to_i
            height = ::Regexp.last_match(2).to_i
            total_pixels = width * height
            similarity = if total_pixels.positive?
                           1.0 - (diff_pixels.to_f / total_pixels)
                         else
                           0.0
                         end

            File.delete(gen_png, ref_png) unless ENV["KEEP_TEST_IMAGES"]

            return {
              success: true,
              similarity: similarity,
              diff_pixels: diff_pixels,
              total_pixels: total_pixels,
            }
          end
        end

        { success: false, error: "Image conversion failed", similarity: nil }
      end
    end
  rescue StandardError => e
    { success: false, error: e.message, similarity: nil }
  end

  # Sanitize diagram name to safe filename
  #
  # @param name [String] Diagram name
  # @return [String] Safe filename
  def sanitize_diagram_filename(name)
    return "unnamed_diagram" if name.nil? || name.empty?

    name.gsub(/[^a-zA-Z0-9_-]/, "_")
  end

  # Find reference SVG file for a diagram
  #
  # @param diagram_name [String] Diagram name
  # @param reference_dir [String] Directory containing reference SVGs
  # @return [String, nil] Path to reference file, or nil if not found
  def find_reference_svg(diagram_name,
reference_dir: "spec/fixtures/ea_svg_references")
    filename = "#{sanitize_diagram_filename(diagram_name)}.svg"
    path = File.join(reference_dir, filename)

    File.exist?(path) ? path : nil
  end
end