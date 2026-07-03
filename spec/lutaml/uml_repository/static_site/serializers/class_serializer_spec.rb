# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::ClassSerializer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { format_definitions: false, include_diagrams: false } }

  describe "#build_map" do
    it "returns a hash keyed by class ID" do
      generalization_map = Hash.new { |h, k| h[k] = [] }
      resolver = Lutaml::UmlRepository::StaticSite::Serializers::InheritanceResolver.new(
        repository, id_generator, options, generalization_map
      )

      serializer = described_class.new(repository, id_generator, options,
                                       resolver)
      result = serializer.build_map

      expect(result).to be_a(Hash)
      expect(result.size).to be >= 1

      result.each_key do |key|
        expect(key).to start_with("cls_")
      end
    end

    it "produces typed SpaClass" do
      generalization_map = Hash.new { |h, k| h[k] = [] }
      resolver = Lutaml::UmlRepository::StaticSite::Serializers::InheritanceResolver.new(
        repository, id_generator, options, generalization_map
      )

      serializer = described_class.new(repository, id_generator, options,
                                       resolver)
      result = serializer.build_map

      result.each_value do |spa_class|
        expect(spa_class).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaClass)
        expect(spa_class.name).to be_a(String)
        expect(spa_class.xmi_id).to be_a(String)
        expect(spa_class.is_abstract).to be(false).or be(true)
      end
    end

    it "includes attribute IDs for classes with attributes" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Attrs"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      pkg.xmi_id = "pkg_1"
      klass = Lutaml::Uml::Class.new
      klass.name = "Widget"
      klass.xmi_id = "cls_w"
      klass.namespace = pkg
      attr = Lutaml::Uml::TopElementAttribute.new
      attr.name = "size"
      attr.type = "Integer"
      klass.attributes = [attr]
      pkg.classes << klass
      doc.packages << pkg

      repo = Lutaml::UmlRepository::Repository.new(document: doc)
      generalization_map = Hash.new { |h, k| h[k] = [] }
      resolver = Lutaml::UmlRepository::StaticSite::Serializers::InheritanceResolver.new(
        repo, id_generator, options, generalization_map
      )

      serializer = described_class.new(repo, id_generator, options, resolver)
      result = serializer.build_map

      spa_class = result.values.first
      expect(spa_class.attributes.size).to eq(1)
      expect(spa_class.attributes.first).to start_with("attr_")
    end

    it "returns nil package for class without package namespace" do
      doc = Lutaml::Uml::Document.new
      doc.name = "NoPkg"
      klass = Lutaml::Uml::Class.new
      klass.name = "Orphan"
      klass.xmi_id = "orphan_cls"
      doc.classes << klass

      repo = Lutaml::UmlRepository::Repository.new(document: doc)
      generalization_map = Hash.new { |h, k| h[k] = [] }
      resolver = Lutaml::UmlRepository::StaticSite::Serializers::InheritanceResolver.new(
        repo, id_generator, options, generalization_map
      )

      serializer = described_class.new(repo, id_generator, options, resolver)
      result = serializer.build_map

      spa_class = result.values.first
      expect(spa_class.package).to be_nil
    end
  end
end
