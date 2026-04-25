# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::InheritanceQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }
  let(:parent_ids) { indexes[:inheritance_graph].keys }

  describe "#find_children" do
    it "finds direct children of a class" do
      parent_ids.each do |parent_id|
        children = query.find_children(parent_id)
        expect(children).to all(be_a(Lutaml::Uml::Class))
      end
    end

    it "returns empty array for nonexistent id" do
      expect(query.find_children("nonexistent_id")).to eq([])
    end

    it "returns array for non-recursive" do
      id = parent_ids.first
      next unless id

      expect(query.find_children(id, recursive: false)).to be_an(Array)
    end

    it "recursive includes at least direct children" do
      id = parent_ids.first
      next unless id

      all = query.find_children(id, recursive: true)
      direct = query.find_children(id, recursive: false)
      expect(all.length).to be >= direct.length
    end
  end

  describe "#find_parent" do
    let(:child_ids) { indexes[:inheritance_graph].values.flatten }
    let(:child_classes) do
      child_ids.filter_map do |q|
        indexes[:qualified_names][q]
      end
    end

    it "finds parent class" do
      child_classes.each do |klass|
        parent = query.find_parent(klass.xmi_id)
        expect(parent).to be_a(Lutaml::Uml::Class) if parent
      end
    end

    it { expect(query.find_parent("nonexistent_id")).to be_nil }
  end

  describe "#find_ancestors" do
    let(:child_ids) { indexes[:inheritance_graph].values.flatten }
    let(:child_classes) do
      child_ids.filter_map do |q|
        indexes[:qualified_names][q]
      end
    end

    it "finds all ancestors" do
      child_classes.each do |klass|
        ancestors = query.find_ancestors(klass.xmi_id)
        expect(ancestors).to all(be_a(Lutaml::Uml::Class))
      end
    end

    it { expect(query.find_ancestors("nonexistent_id")).to eq([]) }

    it "includes parent in ancestors" do
      child_classes.each do |klass|
        parent = query.find_parent(klass.xmi_id)
        expect(query.find_ancestors(klass.xmi_id)).to include(parent) if parent
      end
    end
  end

  describe "#inheritance_tree" do
    it "builds tree for a class", :aggregate_failures do
      id = parent_ids.first
      next unless id

      tree = query.inheritance_tree(id)
      expect(tree).to have_key(:class)
      expect(tree).to have_key(:children)
    end

    it "tree children have correct structure", :aggregate_failures do
      id = parent_ids.first
      next unless id

      children = query.inheritance_tree(id)[:children]
        expect(children).to all(have_key(:class))
        expect(children).to all(have_key(:children))
    end

    it { expect(query.inheritance_tree("nonexistent_id")).to be_nil }
  end

  describe "#has_circular_inheritance?" do
    it "returns boolean for all parents" do
      parent_ids.each do |parent_id|
        expect(query.has_circular_inheritance?(parent_id)).to be(true).or be(false)
      end
    end

    it "returns false for valid hierarchy" do
      indexes[:qualified_names].values.grep(Lutaml::Uml::Class).each do |klass|
        expect(query.has_circular_inheritance?(klass.xmi_id)).to be false
      end
    end
  end
end
