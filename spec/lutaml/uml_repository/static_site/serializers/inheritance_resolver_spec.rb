# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::InheritanceResolver do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { format_definitions: false } }
  let(:generalization_map) { Hash.new { |h, k| h[k] = [] } }

  let(:resolver) do
    described_class.new(repository, id_generator, options, generalization_map)
  end

  describe "#find_generalizations" do
    it "returns empty for class without generalizations" do
      klass = repository.classes_index.first

      result = resolver.find_generalizations(klass)
      expect(result).to eq([])
    end

    it "uses generalization map when available" do
      parent = Lutaml::Uml::Class.new
      parent.name = "Parent"
      parent.xmi_id = "parent_xmi"

      child = Lutaml::Uml::Class.new
      child.name = "Child"
      child.xmi_id = "child_xmi"

      doc = Lutaml::Uml::Document.new
      doc.name = "Inh"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      pkg.classes << parent
      pkg.classes << child
      doc.packages << pkg

      repo = Lutaml::UmlRepository::Repository.new(document: doc)
      gen_map = Hash.new { |h, k| h[k] = [] }
      gen_map["child_xmi"] = ["parent_xmi"]

      inh_resolver = described_class.new(repo, id_generator, options, gen_map)
      result = inh_resolver.find_generalizations(child)

      expect(result).to eq([id_generator.class_id(parent)])
    end
  end

  describe "#find_specializations" do
    it "returns empty for class without specializations" do
      klass = repository.classes_index.first

      result = resolver.find_specializations(klass)
      expect(result).to eq([])
    end
  end

  describe "#compute_inherited_attributes" do
    it "returns empty for class without generalization" do
      klass = repository.classes_index.first

      result = resolver.compute_inherited_attributes(klass)
      expect(result).to eq([])
    end
  end

  describe "#compute_inherited_associations" do
    it "returns empty for class without generalization" do
      klass = repository.classes_index.first

      result = resolver.compute_inherited_associations(klass)
      expect(result).to eq([])
    end
  end
end
