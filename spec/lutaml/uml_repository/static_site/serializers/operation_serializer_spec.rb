# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::OperationSerializer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }

  describe "#build_map" do
    it "returns a hash keyed by operation ID" do
      serializer = described_class.new(repository, id_generator)
      result = serializer.build_map

      expect(result).to be_a(Hash)
      result.each_key do |key|
        expect(key).to start_with("op_")
      end
    end

    it "produces typed SpaOperation values" do
      serializer = described_class.new(repository, id_generator)
      result = serializer.build_map

      result.each_value do |spa_op|
        expect(spa_op).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaOperation)
        expect(spa_op.name).to be_a(String)
      end
    end

    it "returns empty hash for document with no operations" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Empty"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      klass = Lutaml::Uml::Class.new
      klass.name = "NoOps"
      klass.xmi_id = "no_ops_cls"
      pkg.classes << klass
      doc.packages << pkg
      empty_repo = Lutaml::UmlRepository::Repository.new(document: doc)

      serializer = described_class.new(empty_repo, id_generator)
      result = serializer.build_map

      expect(result).to eq({})
    end
  end
end
