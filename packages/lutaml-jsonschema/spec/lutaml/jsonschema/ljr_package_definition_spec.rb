# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::LjrPackageDefinition do
  describe ".definition" do
    it "returns a PackageDefinition" do
      defn = described_class.definition
      expect(defn).to be_a(Lutaml::Store::PackageDefinition)
    end

    it "is named :ljr" do
      defn = described_class.definition
      expect(defn.name).to eq(:ljr)
    end

    it "registers Schema as a model" do
      defn = described_class.definition
      classes = defn.model_classes
      expect(classes).to include(Lutaml::Jsonschema::Schema)
    end

    it "registers Configuration as a model" do
      defn = described_class.definition
      classes = defn.model_classes
      expect(classes).to include(Lutaml::Jsonschema::Configuration)
    end

    it "uses :dollar_id as key for Schema" do
      defn = described_class.definition
      entry = defn.entry_for(Lutaml::Jsonschema::Schema)
      expect(entry.key).to eq(:dollar_id)
    end

    it "uses :title as key for Configuration" do
      defn = described_class.definition
      entry = defn.entry_for(Lutaml::Jsonschema::Configuration)
      expect(entry.key).to eq(:title)
    end

    it "caches the definition" do
      first = described_class.definition
      second = described_class.definition
      expect(first).to equal(second)
    end

    it "generates valid database_store_models" do
      defn = described_class.definition
      models = defn.database_store_models
      expect(models.length).to eq(2)
      models.each do |m|
        expect(m[:model]).to be_a(Class)
        expect(m[:key]).to be_a(Symbol)
      end
    end
  end
end
