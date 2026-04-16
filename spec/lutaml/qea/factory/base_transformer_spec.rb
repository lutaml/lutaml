# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/base_transformer"

RSpec.describe Lutaml::Qea::Factory::BaseTransformer do
  let(:database) { double("Database") }
  let(:transformer) { described_class.new(database) }

  describe "#initialize" do
    it "stores database reference" do
      expect(transformer.database).to eq(database)
    end
  end

  describe "#transform" do
    it "raises NotImplementedError" do
      expect { transformer.transform(nil) }.to raise_error(
        NotImplementedError,
        /must implement #transform/,
      )
    end
  end

  describe "#transform_collection" do
    let(:concrete_transformer) do
      Class.new(described_class) do
        def transform(item)
          return nil if item.nil?

          { transformed: item }
        end
      end.new(database)
    end

    it "transforms empty collection to empty array" do
      result = concrete_transformer.transform_collection([])
      expect(result).to eq([])
    end

    it "transforms nil collection to empty array" do
      result = concrete_transformer.transform_collection(nil)
      expect(result).to eq([])
    end

    it "transforms each item in collection" do
      items = [1, 2, 3]
      result = concrete_transformer.transform_collection(items)
      expect(result).to eq([
                             { transformed: 1 },
                             { transformed: 2 },
                             { transformed: 3 },
                           ])
    end

    it "filters out nil results" do
      items = [1, nil, 3]
      result = concrete_transformer.transform_collection(items)
      expect(result).to eq([
                             { transformed: 1 },
                             { transformed: 3 },
                           ])
    end
  end

  describe "#map_visibility" do
    it "maps 'Public' to 'public'" do
      result = transformer.send(:map_visibility, "Public")
      expect(result).to eq("public")
    end

    it "maps 'Private' to 'private'" do
      result = transformer.send(:map_visibility, "Private")
      expect(result).to eq("private")
    end

    it "maps 'Protected' to 'protected'" do
      result = transformer.send(:map_visibility, "Protected")
      expect(result).to eq("protected")
    end

    it "maps 'Package' to 'package'" do
      result = transformer.send(:map_visibility, "Package")
      expect(result).to eq("package")
    end

    it "defaults nil to 'public'" do
      result = transformer.send(:map_visibility, nil)
      expect(result).to eq("public")
    end

    it "defaults empty string to 'public'" do
      result = transformer.send(:map_visibility, "")
      expect(result).to eq("public")
    end

    it "handles case insensitively" do
      result = transformer.send(:map_visibility, "PRIVATE")
      expect(result).to eq("private")
    end
  end

  describe "#parse_cardinality" do
    it "parses '0..1'" do
      result = transformer.send(:parse_cardinality, "0..1")
      expect(result).to eq(min: "0", max: "1")
    end

    it "parses '1..*'" do
      result = transformer.send(:parse_cardinality, "1..*")
      expect(result).to eq(min: "1", max: "*")
    end

    it "parses single value as both min and max" do
      result = transformer.send(:parse_cardinality, "1")
      expect(result).to eq(min: "1", max: "1")
    end

    it "returns nil values for nil input" do
      result = transformer.send(:parse_cardinality, nil)
      expect(result).to eq(min: nil, max: nil)
    end

    it "returns nil values for empty string" do
      result = transformer.send(:parse_cardinality, "")
      expect(result).to eq(min: nil, max: nil)
    end
  end

  describe "#to_boolean" do
    it "returns false for nil" do
      result = transformer.send(:to_boolean, nil)
      expect(result).to be false
    end

    it "returns true for '1'" do
      result = transformer.send(:to_boolean, "1")
      expect(result).to be true
    end

    it "returns false for '0'" do
      result = transformer.send(:to_boolean, "0")
      expect(result).to be false
    end

    it "returns true for 'true'" do
      result = transformer.send(:to_boolean, "true")
      expect(result).to be true
    end

    it "returns false for 'false'" do
      result = transformer.send(:to_boolean, "false")
      expect(result).to be false
    end

    it "returns true when passed true" do
      result = transformer.send(:to_boolean, true)
      expect(result).to be true
    end

    it "returns false when passed false" do
      result = transformer.send(:to_boolean, false)
      expect(result).to be false
    end

    it "handles case insensitively" do
      result = transformer.send(:to_boolean, "TRUE")
      expect(result).to be true
    end
  end
end
