# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Lutaml::Jsonschema::Spa::Generator do
  let(:fixtures_dir) { File.join(__dir__, "..", "..", "fixtures") }
  let(:schema_set) do
    Lutaml::Jsonschema::SchemaSet.load_from_files(
      File.join(fixtures_dir, "person.json"),
    )
  end

  describe "#generate" do
    it "writes index.html to the output directory" do
      Dir.mktmpdir do |dir|
        output_path = File.join(dir, "output")
        strategy = Lutaml::Jsonschema::Spa::VueInlinedStrategy.new(output_path)

        generator = described_class.new(
          schema_set, output_path,
          metadata: Lutaml::Jsonschema::Spa::Metadata.new(title: "Test"),
          strategy: strategy
        )

        # The strategy needs frontend assets — skip if not built
        unless File.exist?(Lutaml::Jsonschema::Spa::VueInlinedStrategy::FRONTEND_DIST)
          skip "Frontend assets not built"
        end

        generator.generate
        expect(File.exist?(File.join(output_path, "index.html"))).to be true

        html = File.read(File.join(output_path, "index.html"))
        expect(html).to include("window.SCHEMA_DATA")
        expect(html).to include('"title":"Test"')
      end
    end
  end
end
