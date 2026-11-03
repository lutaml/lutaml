#!/usr/bin/env ruby

require "moxml"
require "yaml"

# Parse both XSD files
ctx = Moxml::Context.new
urban_function_doc = ctx.parse(File.read("schemas/urbanFunction.xsd"))
urban_object_doc = ctx.parse(File.read("schemas/urbanObject.xsd"))

# Define namespaces
namespaces = {
  "xs" => "http://www.w3.org/2001/XMLSchema",
  "urf" => "https://www.geospatial.jp/iur/urf/3.2",
  "uro" => "https://www.geospatial.jp/iur/uro/3.2",
}

# Helper to resolve a type to its target element
def resolve_type_to_target(type_name, doc, namespaces)
  # Find the complexType definition
  type_def = doc.xpath(
    "//xs:complexType[@name='#{type_name}']",
    namespaces,
  ).first

  return nil unless type_def

  # Check if it has a sequence with elements
  sequence = type_def.xpath(".//xs:sequence", namespaces).first
  return nil unless sequence

  # Get all xs:element children directly under sequence (not minOccurs="0" wrapper)
  elements = sequence.xpath("./xs:element", namespaces)

  # Check if there's exactly 1 element with a ref attribute
  if elements.length == 1 && elements.first["ref"]
    { "target" => elements.first["ref"] }
  elsif elements.length > 1
    element_names = elements.map do |el|
      el["ref"] || el["name"] || el["type"]
    end.join(", ")
    { "complex_target" => "Multiple elements in sequence: #{element_names}" }
  elsif elements.length == 1 && !elements.first["ref"]
    element_info = elements.first["name"] || elements.first["type"] || "unnamed"
    { "complex_target" => "Single element without ref: #{element_info}" }
  else
    { "complex_target" => "No elements in sequence or empty sequence" }
  end
end

# Process URO elements with substitutionGroup containing _GenericApplicationPropertyOf
def process_uro_generic_application_properties(doc, namespaces)
  elements = doc.xpath(
    "//xs:element[contains(@substitutionGroup, '_GenericApplicationPropertyOf')]",
    namespaces,
  )

  puts "Found #{elements.length} uro elements with _GenericApplicationPropertyOf substitutionGroup"

  results = []

  elements.each do |element|
    element_name = element["name"]
    element_type = element["type"]
    subst_group = element["substitutionGroup"]

    next unless element_type

    # Extract package and class from substitutionGroup
    # Format: xxx:_GenericApplicationPropertyOfYYY
    if subst_group&.include?("_GenericApplicationPropertyOf")
      parts = subst_group.split(":")
      source_package = parts[0]
      class_part = parts[1].sub("_GenericApplicationPropertyOf", "") if parts[1]
    end

    # Extract type name (remove uro: prefix if present)
    type_local_name = element_type.include?(":") ? element_type.split(":").last : element_type

    # Resolve the type
    resolution = resolve_type_to_target(type_local_name, doc, namespaces)

    result = {
      "source" => element_name,
      "source_package" => source_package,
      "source_class" => class_part,
      "type" => element_type,
      "substitutionGroup" => subst_group,
    }

    if resolution
      result.merge!(resolution)
    else
      result["complex_target"] = "Could not resolve type #{element_type}"
    end

    results << result
  end

  results.sort_by { |r| r["source"] }
end

# Process all URF elements with uro: types (including nested ones)
def process_urf_uro_elements(doc, uro_doc, namespaces)
  # Find ALL elements with uro: types
  elements = doc.xpath(
    "//xs:element[@type and starts-with(@type, 'uro:')]",
    namespaces,
  )

  puts "Found #{elements.length} urf elements with uro: types"

  results = []

  elements.each do |element|
    element_name = element["name"]
    element_type = element["type"]

    # Extract type name (remove uro: prefix)
    type_local_name = element_type.sub("uro:", "")

    # Resolve the type in urbanObject.xsd
    resolution = resolve_type_to_target(type_local_name, uro_doc, namespaces)

    result = {
      "source" => element_name,
      "type" => element_type,
    }

    if resolution
      result.merge!(resolution)
    else
      result["complex_target"] = "Could not resolve type #{element_type}"
    end

    results << result
  end

  results.sort_by { |r| r["source"] }
end

puts "=" * 60
puts "Processing URO elements with _GenericApplicationPropertyOf..."
puts "=" * 60
uro_results = process_uro_generic_application_properties(urban_object_doc,
                                                         namespaces)

puts "\n#{'=' * 60}"
puts "Processing URF elements with uro: types..."
puts "=" * 60
urf_results = process_urf_uro_elements(urban_function_doc, urban_object_doc,
                                       namespaces)

# Separate resolved from complex targets
uro_resolved_list = uro_results.select { |r| r["target"] }
uro_complex_list = uro_results.select { |r| r["complex_target"] }
urf_resolved_list = urf_results.select { |r| r["target"] }
urf_complex_list = urf_results.select { |r| r["complex_target"] }

puts "\nResults:"
puts "  URO: #{uro_resolved_list.length} resolved, #{uro_complex_list.length} complex targets"
puts "  URF: #{urf_resolved_list.length} resolved, #{urf_complex_list.length} complex targets"

# Build output with only resolved elements
output = {
  "elements" => {
    "uro" => uro_resolved_list.map do |r|
      result = { "source" => r["source"] }
      result["source_package"] = r["source_package"] if r["source_package"]
      result["source_class"] = r["source_class"] if r["source_class"]
      result["target"] = r["target"]
      result
    end,
    "urf" => urf_resolved_list.map do |r|
      { "source" => r["source"], "target" => r["target"] }
    end,
  },
}

# Output as YAML
puts "\n#{'=' * 60}"
puts "YAML Output:"
puts "=" * 60
puts output.to_yaml

# Display complex targets as warnings at the end
if uro_complex_list.any? || urf_complex_list.any?
  puts "\n#{'=' * 60}"
  puts "WARNINGS: Complex Targets (not included in YAML)"
  puts "=" * 60

  if uro_complex_list.any?
    puts "\nURO elements with complex targets:"
    uro_complex_list.each do |r|
      puts "  - #{r['source']} (#{r['type']}): #{r['complex_target']}"
    end
  end

  if urf_complex_list.any?
    puts "\nURF elements with complex targets:"
    urf_complex_list.each do |r|
      puts "  - #{r['source']} (#{r['type']}): #{r['complex_target']}"
    end
  end
end
