# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea"

RSpec.describe "Tagged Values Integration" do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }

  before do
    skip "QEA file not found" unless File.exist?(qea_file)
  end

  it "loads tagged values from QEA database" do
    document = Lutaml::Qea::Parser.parse(qea_file)

    # Find associations that should have tagged values
    assocs_with_tags = document.associations.select do |assoc|
      assoc.tagged_values && !assoc.tagged_values.empty?
    end

    # Log for debugging
    puts "\nAssociations with tagged values: #{assocs_with_tags.size}"
    if assocs_with_tags.any?
      first_assoc = assocs_with_tags.first
      puts "First association: #{first_assoc.name || first_assoc.xmi_id}"
      puts "Tagged values count: #{first_assoc.tagged_values.size}"
      first_assoc.tagged_values.first(3).each do |tag|
        puts "  - #{tag.name}: #{tag.value}"
      end
    end

    # We expect at least some associations to have tagged values
    # based on the 1110 rows in t_taggedvalue table
    # (Tagged values are on ASSOCIATION_SOURCE, ASSOCIATION_TARGET)
    expect(assocs_with_tags).not_to be_empty
  end
end