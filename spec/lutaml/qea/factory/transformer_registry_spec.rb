# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/factory/transformer_registry"

RSpec.describe Lutaml::Qea::Factory::TransformerRegistry do
  # Reset registry before each test
  before do
    described_class.reset_defaults
  end

  describe ".register" do
    it "registers a transformer for a type" do
      custom_transformer = Class.new
      described_class.register(:custom, custom_transformer)

      expect(described_class.transformer_for(:custom)).to eq(custom_transformer)
    end

    it "handles symbol keys" do
      custom_transformer = Class.new
      described_class.register(:test, custom_transformer)

      expect(described_class.transformer_for(:test)).to eq(custom_transformer)
    end

    it "handles string keys" do
      custom_transformer = Class.new
      described_class.register("test", custom_transformer)

      expect(described_class.transformer_for("test")).to eq(custom_transformer)
    end

    it "overwrites existing registration" do
      transformer1 = Class.new
      transformer2 = Class.new

      described_class.register(:type, transformer1)
      described_class.register(:type, transformer2)

      expect(described_class.transformer_for(:type)).to eq(transformer2)
    end
  end

  describe ".transformer_for" do
    it "returns registered transformer" do
      expect(described_class.transformer_for(:class)).to eq(
        Lutaml::Qea::Factory::ClassTransformer
      )
    end

    it "returns nil for unregistered type" do
      expect(described_class.transformer_for(:unknown)).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true for registered type" do
      expect(described_class.registered?(:class)).to be true
    end

    it "returns false for unregistered type" do
      expect(described_class.registered?(:unknown)).to be false
    end
  end

  describe ".all_transformers" do
    it "returns all registered transformers" do
      transformers = described_class.all_transformers

      expect(transformers).to be_a(Hash)
      expect(transformers).to include(
        class: Lutaml::Qea::Factory::ClassTransformer,
        association: Lutaml::Qea::Factory::AssociationTransformer,
        generalization: Lutaml::Qea::Factory::GeneralizationTransformer
      )
    end

    it "returns a copy of the registry" do
      transformers = described_class.all_transformers
      transformers[:new] = Class.new

      expect(described_class.transformer_for(:new)).to be_nil
    end
  end

  describe ".clear" do
    it "removes all registrations" do
      described_class.clear

      expect(described_class.all_transformers).to be_empty
    end
  end

  describe ".reset_defaults" do
    it "restores default registrations" do
      described_class.clear
      expect(described_class.all_transformers).to be_empty

      described_class.reset_defaults

      expect(described_class.transformer_for(:class)).to eq(
        Lutaml::Qea::Factory::ClassTransformer
      )
    end
  end

  describe "default registrations" do
    it "registers class transformer" do
      expect(described_class.transformer_for(:class)).to eq(
        Lutaml::Qea::Factory::ClassTransformer
      )
    end

    it "registers interface transformer" do
      expect(described_class.transformer_for(:interface)).to eq(
        Lutaml::Qea::Factory::ClassTransformer
      )
    end

    it "registers package transformer" do
      expect(described_class.transformer_for(:package)).to eq(
        Lutaml::Qea::Factory::PackageTransformer
      )
    end

    it "registers association transformer" do
      expect(described_class.transformer_for(:association)).to eq(
        Lutaml::Qea::Factory::AssociationTransformer
      )
    end

    it "registers generalization transformer" do
      expect(described_class.transformer_for(:generalization)).to eq(
        Lutaml::Qea::Factory::GeneralizationTransformer
      )
    end

    it "registers attribute transformer" do
      expect(described_class.transformer_for(:attribute)).to eq(
        Lutaml::Qea::Factory::AttributeTransformer
      )
    end

    it "registers operation transformer" do
      expect(described_class.transformer_for(:operation)).to eq(
        Lutaml::Qea::Factory::OperationTransformer
      )
    end

    it "registers diagram transformer" do
      expect(described_class.transformer_for(:diagram)).to eq(
        Lutaml::Qea::Factory::DiagramTransformer
      )
    end
  end
end