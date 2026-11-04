# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe Lutaml::Jsonschema::Spa::Generator do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }
  let(:schema_set) do
    Lutaml::Jsonschema::SchemaSet.load_from_files(
      File.join(fixtures_dir, "interagent_simple.json"),
    )
  end

  describe "#generate" do
    it "generates HTML with inlined JS and CSS" do
      Dir.mktmpdir do |dir|
        metadata = Lutaml::Jsonschema::Spa::Metadata.new(title: "Test")
        described_class.new(schema_set, dir, metadata: metadata).generate

        html = File.read(File.join(dir, "index.html"))
        expect(html).to include("<!DOCTYPE html>")
        expect(html).to include("window.SCHEMA_DATA")
        expect(html).to include("<style>")
        expect(html).to include("<script>")
      end
    end

    it "includes resolved property data in SCHEMA_DATA" do
      Dir.mktmpdir do |dir|
        described_class.new(schema_set, dir).generate

        html = File.read(File.join(dir, "index.html"))
        data = JSON.parse(html[/window\.SCHEMA_DATA\s*=\s*(\{.*?\});/m, 1])
        schema = data["schemas"].first

        post_def = schema["definitions"].find { |d| d["name"] == "post" }
        created_at = post_def["properties"].find do |p|
          p["name"] == "created_at"
        end
        expect(created_at["type"]).to eq("string")
        expect(created_at["format"]).to eq("date-time")
      end
    end

    it "accepts a custom output strategy" do
      captured_json = nil
      strategy = Lutaml::Jsonschema::Spa::OutputStrategy.new("/tmp/test")
      strategy.define_singleton_method(:write) do |json_data|
        captured_json = json_data
      end

      metadata = Lutaml::Jsonschema::Spa::Metadata.new(title: "Custom")
      generator = described_class.new(schema_set, "/tmp/test",
                                      metadata: metadata, strategy: strategy)
      generator.generate

      expect(captured_json).to be_a(String)
      data = JSON.parse(captured_json)
      expect(data["metadata"]["title"]).to eq("Custom")
    end
  end
end
