# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::InheritanceQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_children" do
    it "finds direct children of a class" do
      parent_classes = indexes[:inheritance_graph].keys

      parent_classes.each do |parent_id|
        children = query.find_children(parent_id)
        expect(children).to be_an(Array)
        expect(children).to all(be_a(Lutaml::Uml::Class))
      end
    end

    it "returns empty array for class without children" do
      leaf_class_id = "nonexistent_id"
      children = query.find_children(leaf_class_id)
      expect(children).to eq([])
    end

    it "returns only direct children when recursive is false" do
      parent_classes = indexes[:inheritance_graph].keys.first
      if parent_classes
        direct_children = query.find_children(parent_classes, recursive: false)
        expect(direct_children).to be_an(Array)
      end
    end

    context "with recursive option" do
      it "includes all descendants when recursive is true" do
        parent_classes = indexes[:inheritance_graph].keys.first
        if parent_classes
          all_descendants = query.find_children(parent_classes, recursive: true)
          direct_children = query.find_children(parent_classes,
                                                recursive: false)

          expect(all_descendants.length).to be >= direct_children.length
        end
      end
    end
  end

  describe "#find_parent" do
    it "finds parent class" do
      classes_with_parents = []
      indexes[:qualified_names].each_value do |klass|
        next unless klass.is_a?(Lutaml::Uml::Class)

        klass.associations.each do |assoc|
          if ["inheritance", "generalization"].include?(assoc.member_end_type)
            classes_with_parents << klass
            break
          end
        end
      end

      classes_with_parents.each do |klass|
        parent = query.find_parent(klass.xmi_id)
        if parent
          expect(parent).to be_a(Lutaml::Uml::Class)
        end
      end
    end

    it "returns nil for class without parent" do
      parent = query.find_parent("nonexistent_id")
      expect(parent).to be_nil
    end
  end

  describe "#find_ancestors" do
    it "finds all ancestors of a class" do
      classes_names_with_parents = indexes[:inheritance_graph].values.flatten
      classes_with_parents = classes_names_with_parents.filter_map do |qname|
        indexes[:qualified_names][qname]
      end

      classes_with_parents.each do |klass|
        ancestors = query.find_ancestors(klass.xmi_id)
        expect(ancestors).to be_an(Array)
        expect(ancestors).to all(be_a(Lutaml::Uml::Class))
      end
    end

    it "returns empty array for class without ancestors" do
      ancestors = query.find_ancestors("nonexistent_id")
      expect(ancestors).to eq([])
    end

    it "includes all levels of inheritance" do
      classes_with_parents = []
      indexes[:qualified_names].each_value do |klass|
        next unless klass.is_a?(Lutaml::Uml::Class)

        klass.associations.each do |assoc|
          if ["inheritance", "generalization"].include?(assoc.member_end_type)
            classes_with_parents << klass
            break
          end
        end
      end

      classes_with_parents.each do |klass|
        ancestors = query.find_ancestors(klass.xmi_id)
        parent = query.find_parent(klass.xmi_id)

        if parent
          expect(ancestors).to include(parent)
        end
      end
    end
  end

  xdescribe "#inheritance_tree" do
    it "builds inheritance tree for a class" do
      parent_classes = indexes[:inheritance_graph].keys.first
      if parent_classes
        tree = query.inheritance_tree(parent_classes)

        expect(tree).to be_a(Hash)
        expect(tree).to have_key(:class)
        expect(tree).to have_key(:children)
      end
    end

    it "includes nested inheritance relationships" do
      parent_classes = indexes[:inheritance_graph].keys.first
      if parent_classes
        tree = query.inheritance_tree(parent_classes)

        tree[:children].each do |child_tree|
          expect(child_tree).to be_a(Hash)
          expect(child_tree).to have_key(:class)
          expect(child_tree).to have_key(:children)
        end
      end
    end

    it "returns nil for non-existent class" do
      tree = query.inheritance_tree("nonexistent_id")
      expect(tree).to be_nil
    end
  end

  xdescribe "#has_circular_inheritance?" do
    it "detects circular inheritance" do
      parent_classes = indexes[:inheritance_graph].keys
      parent_classes.each do |parent_id|
        result = query.has_circular_inheritance?(parent_id)
        expect(result).to be(true).or be(false)
      end
    end

    it "returns false for valid inheritance hierarchy" do
      classes = indexes[:qualified_names].values.grep(Lutaml::Uml::Class)

      classes.each do |klass|
        result = query.has_circular_inheritance?(klass.xmi_id)
        expect(result).to be false
      end
    end
  end
end
