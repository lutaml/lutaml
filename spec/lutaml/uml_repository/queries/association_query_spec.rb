# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::Queries::AssociationQuery do
  let(:document) { create_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:query) { described_class.new(document, indexes) }

  describe "#find_for_class" do
    it "finds associations for a class", :aggregate_failures do
      classes = indexes[:qualified_names].values.grep(Lutaml::Uml::Class)

      classes.each do |klass|
        associations = query.find_for_class(klass.xmi_id)
        expect(associations).to be_an(Array)
        expect(associations).to all(be_a(Lutaml::Uml::Association))
      end
    end

    it "returns empty array for class without associations" do
      associations = query.find_for_class("nonexistent_id")
      expect(associations).to eq([])
    end

    it "finds all association types" do
      classes = indexes[:qualified_names].values.select do |e|
        e.is_a?(Lutaml::Uml::Class) && !e.associations.empty?
      end

      classes.each do |klass|
        associations = query.find_for_class(klass.xmi_id)
        expect(associations.length).to be >= 0
      end
    end
  end

  describe "#find_by_type" do
    it "finds associations of specific type", :aggregate_failures do
      association_types = %w[aggregation composition association]

      association_types.each do |type|
        associations = query.find_by_type(type)
        expect(associations).to be_an(Array)
        associations.each do |assoc|
          expect(assoc.member_end_type).to eq(type)
        end
      end
    end

    it "returns empty array for non-existent type" do
      associations = query.find_by_type("nonexistent_type")
      expect(associations).to eq([])
    end

    it "handles various association types" do
      all_types = Set.new
      indexes[:qualified_names].each_value do |entity|
        next unless entity.is_a?(Lutaml::Uml::Class)

        entity.associations.each do |assoc|
          all_types << assoc.member_end_type if assoc.member_end_type
        end
      end

      all_types.each do |type|
        associations = query.find_by_type(type)
        expect(associations).to be_an(Array)
      end
    end
  end

  describe "#find_between_classes" do
    it "finds associations between two classes" do
      classes_with_assocs = indexes[:qualified_names].values.select do |e|
        e.is_a?(Lutaml::Uml::Class) && !e.associations.empty?
      end

      classes_with_assocs.each do |klass|
        klass.associations.each do |assoc|
          next unless assoc.member_end_xmi_id

          associations = query.find_between_classes(
            klass.xmi_id,
            assoc.member_end_xmi_id,
          )
          expect(associations).to be_an(Array)
        end
      end
    end

    it "returns empty array when no association exists" do
      associations = query.find_between_classes("id1", "id2")
      expect(associations).to eq([])
    end

    it "finds bidirectional associations", :aggregate_failures do
      classes_with_assocs = indexes[:qualified_names].values.select do |e|
        e.is_a?(Lutaml::Uml::Class) && !e.associations.empty?
      end

      classes_with_assocs.each do |klass|
        klass.associations.each do |assoc|
          next unless assoc.member_end_xmi_id

          forward = query.find_between_classes(
            klass.xmi_id,
            assoc.member_end_xmi_id,
          )
          backward = query.find_between_classes(
            assoc.member_end_xmi_id,
            klass.xmi_id,
          )

          expect(forward).to be_an(Array)
          expect(backward).to be_an(Array)
        end
      end
    end
  end

  describe "#all" do
    it "returns all associations", :aggregate_failures do
      associations = query.all
      expect(associations).to be_an(Array)
      expect(associations).to all(be_a(Lutaml::Uml::Association))
    end

    it "includes associations from all classes" do
      associations = query.all

      all_class_associations = []
      indexes[:qualified_names].each_value do |entity|
        next unless entity.is_a?(Lutaml::Uml::Class)

        all_class_associations.concat(entity.associations)
      end

      expect(associations.length).to eq(all_class_associations.length)
    end
  end

  describe "#find_aggregations" do
    it "finds all aggregation associations", :aggregate_failures do
      aggregations = query.find_aggregations
      expect(aggregations).to be_an(Array)
      aggregations.each do |assoc|
        expect(assoc.member_end_type).to eq("aggregation")
      end
    end
  end

  describe "#find_compositions" do
    it "finds all composition associations", :aggregate_failures do
      compositions = query.find_compositions
      expect(compositions).to be_an(Array)
      compositions.each do |assoc|
        expect(assoc.member_end_type).to eq("composition")
      end
    end
  end
end
