# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

# Check if fiddle is available (required by tty-prompt on Windows Ruby 4.0+)
fiddle_available = begin
  require "fiddle"
  true
rescue LoadError
  false
end

# Only load interactive_builder if fiddle is available
if fiddle_available
  require "lutaml/xsd/interactive_builder"
end

RSpec.describe Lutaml::Xsd::InteractiveBuilder do
  let(:entry_points) { [File.join(fixtures_path, "simple_schema.xsd")] }
  let(:options) { { verbose: false, output: output_file } }
  let(:output_file) { File.join(tmp_dir, "repository.yml") }
  let(:tmp_dir) do
    dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(dir)
    dir
  end
  let(:fixtures_path) do
    File.join(__dir__, "../../fixtures/interactive_builder")
  end

  subject(:builder) { described_class.new(entry_points, options) }

  before do
    # Create fixtures directory if it doesn't exist
    FileUtils.mkdir_p(fixtures_path)

    # Create a simple test schema
    simple_schema = <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/simple"
                 elementFormDefault="qualified">
        <xs:element name="root" type="xs:string"/>
      </xs:schema>
    XSD

    File.write(File.join(fixtures_path, "simple_schema.xsd"), simple_schema)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.rm_rf(fixtures_path)
    # Clean up session file if it exists
    FileUtils.rm_f(Lutaml::Xsd::InteractiveBuilder::SESSION_FILE)
  end

  describe "#initialize" do
    it "initializes with entry points and options" do
      expect(builder.entry_points).to eq(entry_points)
      expect(builder.options).to eq(options)
    end

    it "initializes empty collections" do
      expect(builder.resolved_mappings).to eq([])
      expect(builder.namespace_mappings).to eq([])
      expect(builder.pattern_mappings).to eq([])
      expect(builder.pending_schemas).to eq([])
      expect(builder.processed_schemas).to eq([])
    end

    it "creates a TTY::Prompt instance" do
      expect(builder.prompt).to be_a(TTY::Prompt)
    end
  end

  describe "#run" do
    context "with simple schema without dependencies" do
      let(:entry_points) { [File.join(fixtures_path, "simple_schema.xsd")] }

      it "processes the schema successfully" do
        # Mock prompt to avoid interactive input
        allow(builder).to receive(:prompt).and_return(double(select: :skip,
                                                             yes?: false, ask: ""))

        expect { builder.run }.not_to raise_error
        expect(File.exist?(output_file)).to be true
      end

      it "generates configuration file" do
        allow(builder).to receive(:prompt).and_return(double(select: :skip,
                                                             yes?: false, ask: ""))

        builder.run

        config = YAML.load_file(output_file)
        expect(config["files"]).to eq(entry_points)
        expect(config).to have_key("schema_location_mappings")
        expect(config).to have_key("namespace_mappings")
      end
    end

    context "with schema containing imports" do
      let(:main_schema_path) do
        File.join(fixtures_path, "main_with_import.xsd")
      end
      let(:imported_schema_path) { File.join(fixtures_path, "imported.xsd") }
      let(:entry_points) { [main_schema_path] }

      before do
        # Create main schema with import
        main_schema = <<~XSD
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     xmlns:imp="http://example.com/imported"
                     targetNamespace="http://example.com/main"
                     elementFormDefault="qualified">
            <xs:import namespace="http://example.com/imported"
                       schemaLocation="imported.xsd"/>
            <xs:element name="root" type="xs:string"/>
          </xs:schema>
        XSD

        # Create imported schema
        imported_schema = <<~XSD
          <?xml version="1.0" encoding="UTF-8"?>
          <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                     targetNamespace="http://example.com/imported"
                     elementFormDefault="qualified">
            <xs:element name="imported" type="xs:string"/>
          </xs:schema>
        XSD

        File.write(main_schema_path, main_schema)
        File.write(imported_schema_path, imported_schema)
      end

      it "discovers import dependencies" do
        # Mock user selecting the imported schema
        allow(builder).to receive(:prompt).and_return(
          double(select: :skip, yes?: false, ask: ""),
        )

        builder.run

        # Verify the schema was processed
        expect(builder.processed_schemas).to include(main_schema_path)
      end
    end
  end

  describe "#search_for_schema" do
    let(:search_paths) { [fixtures_path] }
    let(:options) { { search_paths: search_paths, output: output_file } }

    before do
      # Create test schemas
      File.write(File.join(fixtures_path, "test1.xsd"), "<xs:schema/>")
      File.write(File.join(fixtures_path, "test2.xsd"), "<xs:schema/>")

      # Create subdirectory with another schema
      subdir = File.join(fixtures_path, "subdir")
      FileUtils.mkdir_p(subdir)
      File.write(File.join(subdir, "test1.xsd"), "<xs:schema/>")
    end

    it "finds unique matches" do
      matches = builder.send(:search_for_schema, "test2.xsd")
      expect(matches.size).to eq(1)
      expect(matches.first).to include("test2.xsd")
    end

    it "finds multiple matches" do
      matches = builder.send(:search_for_schema, "test1.xsd")
      expect(matches.size).to eq(2)
    end

    it "returns empty array when no matches found" do
      matches = builder.send(:search_for_schema, "nonexistent.xsd")
      expect(matches).to be_empty
    end
  end

  describe "#url?" do
    it "detects HTTP URLs" do
      expect(builder.send(:url?, "http://example.com/schema.xsd")).to be true
    end

    it "detects HTTPS URLs" do
      expect(builder.send(:url?, "https://example.com/schema.xsd")).to be true
    end

    it "rejects file paths" do
      expect(builder.send(:url?, "/path/to/schema.xsd")).to be false
      expect(builder.send(:url?, "schema.xsd")).to be false
    end

    it "rejects relative paths" do
      expect(builder.send(:url?, "../schema.xsd")).to be false
      expect(builder.send(:url?, "./schema.xsd")).to be false
    end
  end

  describe "#format_file_size" do
    it "formats bytes" do
      expect(builder.send(:format_file_size, 500)).to eq("500 B")
    end

    it "formats kilobytes" do
      expect(builder.send(:format_file_size, 2048)).to eq("2.0 KB")
    end

    it "formats megabytes" do
      expect(builder.send(:format_file_size, 2_097_152)).to eq("2.0 MB")
    end
  end

  describe "#namespace_exists?" do
    before do
      builder.instance_variable_set(:@namespace_mappings, [
                                      { "prefix" => "test", "uri" => "http://example.com/test" },
                                    ])
    end

    it "returns true for existing namespace" do
      expect(builder.send(:namespace_exists?,
                          "http://example.com/test")).to be true
    end

    it "returns false for non-existing namespace" do
      expect(builder.send(:namespace_exists?,
                          "http://example.com/other")).to be false
    end
  end

  describe "#add_mapping" do
    it "adds a schema location mapping" do
      builder.send(:add_mapping, "from.xsd", "to.xsd", "test reason")

      expect(builder.resolved_mappings.size).to eq(1)
      expect(builder.resolved_mappings.first).to include(
        "from" => "from.xsd",
        "to" => "to.xsd",
        "comment" => "Found by: test reason",
      )
    end
  end

  describe "#save_configuration" do
    before do
      builder.instance_variable_set(:@resolved_mappings, [
                                      { "from" => "test.xsd", "to" => "/path/to/test.xsd", "comment" => "Found by: test" },
                                    ])
      builder.instance_variable_set(:@namespace_mappings, [
                                      { "prefix" => "test", "uri" => "http://example.com/test" },
                                    ])
    end

    it "creates configuration file" do
      allow(builder).to receive(:output)
      builder.send(:save_configuration)

      expect(File.exist?(output_file)).to be true
    end

    it "includes all required sections" do
      allow(builder).to receive(:output)
      builder.send(:save_configuration)

      content = File.read(output_file)
      expect(content).to include("files:")
      expect(content).to include("schema_location_mappings:")
      expect(content).to include("namespace_mappings:")
    end
  end

  describe "session management" do
    let(:session_file) { Lutaml::Xsd::InteractiveBuilder::SESSION_FILE }

    describe "#save_session" do
      it "saves session data to file" do
        builder.instance_variable_set(:@dependency_count, 5)
        builder.send(:save_session)

        expect(File.exist?(session_file)).to be true

        data = YAML.load_file(session_file)
        expect(data["dependency_count"]).to eq(5)
      end
    end

    describe "#load_session" do
      before do
        session_data = {
          "entry_points" => entry_points,
          "resolved_mappings" => [{ "from" => "a", "to" => "b" }],
          "dependency_count" => 3,
        }
        File.write(session_file, session_data.to_yaml)
      end

      it "loads session data from file" do
        allow(builder).to receive(:output)
        builder.send(:load_session)

        expect(builder.resolved_mappings.size).to eq(1)
        expect(builder.instance_variable_get(:@dependency_count)).to eq(3)
      end
    end

    describe "#session_exists?" do
      it "returns true when session file exists" do
        FileUtils.touch(session_file)
        expect(builder.send(:session_exists?)).to be true
      end

      it "returns false when session file does not exist" do
        expect(builder.send(:session_exists?)).to be false
      end
    end

    describe "#cleanup_session" do
      before do
        FileUtils.touch(session_file)
      end

      it "removes session file" do
        builder.send(:cleanup_session)
        expect(File.exist?(session_file)).to be false
      end
    end
  end

  describe "#create_pattern_from_location" do
    it "creates regex pattern from relative path" do
      location = "../../../gml/3.2.1/gml.xsd"
      pattern = builder.send(:create_pattern_from_location, location)

      # The pattern should contain escaped regex for ../ paths
      expect(pattern).to include('gml/3\\.2\\.1')
      expect(pattern).to include('(.+\\.xsd)$')
    end
  end

  describe "#find_pattern_match" do
    before do
      builder.instance_variable_set(:@pattern_mappings, [
                                      {
                                        "from" => '(?:\\.\\./)+gml/(.+\\.xsd)$',
                                        "to" => '/path/to/gml/\\1',
                                        "pattern" => true,
                                      },
                                    ])
    end

    it "finds matching pattern" do
      match = builder.send(:find_pattern_match, "../gml/feature.xsd")
      expect(match).not_to be_nil
      expect(match["from"]).to include("gml")
    end

    it "returns nil for non-matching location" do
      match = builder.send(:find_pattern_match, "other/file.xsd")
      expect(match).to be_nil
    end
  end

  describe "error handling" do
    context "with invalid entry point" do
      let(:entry_points) { ["/nonexistent/schema.xsd"] }

      it "handles missing entry points gracefully" do
        allow(builder).to receive(:prompt).and_return(
          double(select: :skip, yes?: false, ask: ""),
        )
        allow(builder).to receive(:error)

        expect { builder.run }.not_to raise_error
      end
    end

    context "with unparseable schema" do
      let(:invalid_schema_path) { File.join(fixtures_path, "invalid.xsd") }
      let(:entry_points) { [invalid_schema_path] }

      before do
        File.write(invalid_schema_path, "not valid XML")
      end

      it "handles parse errors gracefully" do
        allow(builder).to receive(:prompt).and_return(
          double(select: :skip, yes?: false, ask: ""),
        )
        allow(builder).to receive(:verbose_output)

        expect { builder.run }.not_to raise_error
      end
    end
  end
end
