# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::AttributeSerializer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { format_definitions: false } }

  describe "#build_map" do
    it "returns a hash keyed by attribute ID" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      expect(result).to be_a(Hash)
      result.each_key do |key|
        expect(key).to start_with("attr_")
      end
    end

    it "produces typed SpaAttribute values" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      result.each_value do |spa_attr|
        expect(spa_attr).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaAttribute)
        expect(spa_attr.name).to be_a(String)
        expect(spa_attr.owner_name).to be_a(String)
      end
    end

    it "returns empty hash for document with no class attributes" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Empty"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      klass = Lutaml::Uml::Class.new
      klass.name = "EmptyClass"
      klass.xmi_id = "empty_cls"
      pkg.classes << klass
      doc.packages << pkg
      empty_repo = Lutaml::UmlRepository::Repository.new(document: doc)

      serializer = described_class.new(empty_repo, id_generator, options)
      result = serializer.build_map

      expect(result).to eq({})
    end
  end
end
