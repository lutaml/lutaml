# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::MetadataBuilder do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }

  describe "#build" do
    it "returns typed SpaMetadata" do
      builder = described_class.new(repository)
      result = builder.build

      expect(result).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaMetadata)
      expect(result.generator).to eq("LutaML Static Site Generator")
      expect(result.version).to eq("1.0")
    end

    it "includes statistics" do
      builder = described_class.new(repository)
      result = builder.build

      stats = result.statistics
      expect(stats).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaStatistics)
      expect(stats.packages).to be >= 1
      expect(stats.classes).to be >= 1
    end

    it "generates ISO 8601 timestamp" do
      builder = described_class.new(repository)
      result = builder.build

      expect(result.generated).to match(/^\d{4}-\d{2}-\d{2}T/)
    end

    it "counts attributes correctly with nil handling" do
      doc = Lutaml::Uml::Document.new
      doc.name = "NoAttrs"
      pkg = Lutaml::Uml::Package.new
      pkg.name = "Pkg"
      doc.packages << pkg
      no_attr_repo = Lutaml::UmlRepository::Repository.new(document: doc)

      builder = described_class.new(no_attr_repo)
      result = builder.build

      expect(result.statistics.attributes).to eq(0)
      expect(result.statistics.operations).to eq(0)
    end
  end
end
