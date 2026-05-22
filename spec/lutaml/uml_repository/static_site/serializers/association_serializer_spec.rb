# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::AssociationSerializer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { include_diagrams: true } }

  describe "#build_map" do
    it "returns a hash keyed by association ID" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      expect(result).to be_a(Hash)
      result.each_key do |key|
        expect(key).to start_with("assoc_")
      end
    end

    it "produces typed SpaAssociation values" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      result.each_value do |spa_assoc|
        expect(spa_assoc).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaAssociation)
        expect(spa_assoc.type).to eq("Association")
      end
    end

    it "returns empty hash for document with no associations" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Empty"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      doc.packages << pkg
      empty_repo = Lutaml::UmlRepository::Repository.new(document: doc)

      serializer = described_class.new(empty_repo, id_generator, options)
      result = serializer.build_map

      expect(result).to eq({})
    end
  end
end
