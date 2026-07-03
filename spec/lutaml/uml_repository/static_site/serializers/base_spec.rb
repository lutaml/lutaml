# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::Base do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { include_diagrams: true } }
  let(:serializer) { described_class.new(repository, id_generator, options) }

  describe "#initialize" do
    it "exposes repository, id_generator, and options" do
      expect(serializer.repository).to eq(repository)
      expect(serializer.id_generator).to eq(id_generator)
      expect(serializer.options).to eq(options)
    end

    it "defaults options to empty hash" do
      base = described_class.new(repository, id_generator)
      expect(base.options).to eq({})
    end
  end

  describe "#find_class_associations" do
    it "returns association IDs for a class" do
      klass = repository.classes_index.first

      result = serializer.find_class_associations(klass)

      expected = repository.associations_of(klass).map do |a|
        id_generator.association_id(a)
      end
      expect(result).to eq(expected)
    end

    it "returns empty array for class with no associations" do
      klass = repository.classes_index.first
      empty_repo = Lutaml::UmlRepository::Repository.new(
        document: create_simple_test_document,
      )
      empty_serializer = described_class.new(empty_repo, id_generator, options)

      result = empty_serializer.find_class_associations(klass)
      expect(result).to eq([])
    end
  end

  describe "#find_assoc_by_id" do
    it "finds association by generated ID" do
      assoc = repository.associations_index.first
      next unless assoc

      target_id = id_generator.association_id(assoc)
      result = serializer.find_assoc_by_id(target_id)

      expect(result).to eq(assoc)
    end

    it "returns nil when not found" do
      result = serializer.find_assoc_by_id("assoc_nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#resolve_assoc_role" do
    it "returns empty string for nil owner/member attribute names" do
      assoc = repository.associations_index.first
      next unless assoc

      result = serializer.resolve_assoc_role(assoc, "NONEXISTENT_XMI")
      expect(result).to eq("")
    end
  end

  describe "#package_diagrams" do
    it "returns diagrams when include_diagrams is true" do
      pkg = repository.packages_index.first
      result = serializer.package_diagrams(pkg)
      expect(result).to be_a(Array)
    end

    it "returns empty array when include_diagrams is false" do
      no_diag_serializer = described_class.new(
        repository, id_generator, { include_diagrams: false }
      )
      pkg = repository.packages_index.first

      result = no_diag_serializer.package_diagrams(pkg)
      expect(result).to eq([])
    end
  end
end
