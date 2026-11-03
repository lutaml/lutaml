# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::Metadata do
  describe ".new" do
    it "defaults theme to light" do
      metadata = described_class.new
      expect(metadata.theme).to eq("light")
    end

    it "accepts all attributes" do
      metadata = described_class.new(
        title: "API Docs",
        version: "2.0",
        description: "My API",
        base_url: "https://api.example.com",
        theme: "dark",
        appearance: { "logos" => {} },
      )
      expect(metadata.title).to eq("API Docs")
      expect(metadata.version).to eq("2.0")
      expect(metadata.description).to eq("My API")
      expect(metadata.base_url).to eq("https://api.example.com")
      expect(metadata.theme).to eq("dark")
      expect(metadata.appearance).to eq({ "logos" => {} })
    end
  end

  describe "JSON serialization" do
    it "uses camelCase keys" do
      metadata = described_class.new(
        title: "Test",
        base_url: "https://example.com",
        theme: "dark",
      )
      parsed = JSON.parse(metadata.to_json)
      expect(parsed["title"]).to eq("Test")
      expect(parsed["baseUrl"]).to eq("https://example.com")
      expect(parsed["theme"]).to eq("dark")
    end

    it "round-trips through JSON" do
      metadata = described_class.new(
        title: "Round Trip",
        version: "3.0",
        description: "Test",
        base_url: "https://api.test.com",
        theme: "dark",
      )
      reparsed = described_class.from_json(metadata.to_json)
      expect(reparsed.title).to eq("Round Trip")
      expect(reparsed.version).to eq("3.0")
      expect(reparsed.theme).to eq("dark")
      expect(reparsed.base_url).to eq("https://api.test.com")
    end
  end
end
