require "spec_helper"
require "stringio"
require "fileutils"

RSpec.describe Expressir::Commands::Coverage do
  let(:output) { StringIO.new }
  let(:test_manifest_path) do
    File.join("spec", "fixtures", "test_manifest.yml")
  end
  let(:sample_schema_path) { File.join("spec", "syntax", "syntax.exp") }

  before do
    # Redirect stdout for all tests
    allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
    allow($stdout).to receive(:print) { |msg| output.print(msg) }
  end

  describe "#run with single file" do
    let(:options) { { format: "text" } }
    let(:command) { described_class.new(options) }

    it "processes a single EXPRESS file" do
      command.run([sample_schema_path])

      expect(output.string).to include("Processing file: #{sample_schema_path}")
      expect(output.string).to include("EXPRESS Documentation Coverage")
      expect(output.string).to include("Coverage Percentage")
      expect(output.string).to include("Total Entities")
    end

    it "outputs JSON format when requested" do
      json_command = described_class.new(format: "json")
      json_command.run([sample_schema_path])

      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      json_content = File.read("coverage_report.json")
      expect(json_content).to include("{")
      expect(json_content).to include("\"overall\":")
      expect(json_content).to include("\"total_entities\":")
      expect(json_content).to include("\"coverage_percentage\":")

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end

    it "outputs YAML format when requested" do
      yaml_command = described_class.new(format: "yaml")
      yaml_command.run([sample_schema_path])

      expect(output.string).to include("YAML coverage report written to: coverage_report.yaml")
      expect(File.exist?("coverage_report.yaml")).to be true

      yaml_content = File.read("coverage_report.yaml")
      expect(yaml_content).to include("---")
      expect(yaml_content).to include("overall:")
      expect(yaml_content).to include("total_entities:")
      expect(yaml_content).to include("coverage_percentage:")

      # Clean up
      FileUtils.rm_f("coverage_report.yaml")
    end
  end

  describe "#run with exclusions" do
    let(:options) { { format: "json", exclude: ["PARAMETER", "VARIABLE"] } }
    let(:command) { described_class.new(options) }

    it "applies exclusions correctly" do
      command.run([sample_schema_path])

      # Check that JSON file was created
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      # Parse JSON output to verify exclusions were applied
      json_output = JSON.parse(File.read("coverage_report.json"))

      # Should have fewer entities when exclusions are applied
      expect(json_output["overall"]["total_entities"]).to be > 0

      # Verify no excluded entity types appear in undocumented list
      if json_output["files"].any?
        undocumented = json_output["files"].first["undocumented"] || []
        parameter_entities = undocumented.select do |e|
          e["type"] == "PARAMETER"
        end
        variable_entities = undocumented.select { |e| e["type"] == "VARIABLE" }

        expect(parameter_entities).to be_empty
        expect(variable_entities).to be_empty
      end

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end

    it "applies TYPE subtype exclusions" do
      type_exclusion_command = described_class.new(format: "json",
                                                   exclude: ["TYPE:SELECT"])
      type_exclusion_command.run([sample_schema_path])

      # Should successfully exclude SELECT types without errors
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end

    it "handles multiple exclusions" do
      multi_exclusion_command = described_class.new(format: "json",
                                                    exclude: [
                                                      "PARAMETER", "TYPE:SELECT", "ENUMERATION_ITEM"
                                                    ])
      multi_exclusion_command.run([sample_schema_path])

      # Should successfully apply multiple exclusions without errors
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end
  end

  describe "#run with directory" do
    let(:options) { { format: "json" } }
    let(:command) { described_class.new(options) }

    it "processes all EXPRESS files in a directory" do
      command.run(["spec/fixtures/examples"])

      # Check that JSON file was created
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      json_output = JSON.parse(File.read("coverage_report.json"))

      expect(json_output["overall"]["total_entities"]).to be > 0
      expect(json_output["files"].size).to be > 1
      expect(json_output["directories"]).not_to be_empty

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end
  end

  describe "#run with multiple files" do
    let(:options) { { format: "json" } }
    let(:command) { described_class.new(options) }
    let(:remark_schema_path) { File.join("spec", "syntax", "remark.exp") }

    it "processes multiple EXPRESS files" do
      command.run([sample_schema_path, remark_schema_path])

      # Check that JSON file was created
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      json_output = JSON.parse(File.read("coverage_report.json"))

      expect(json_output["overall"]["total_entities"]).to be > 0
      expect(json_output["files"].size).to eq(2)

      file_names = json_output["files"].map { |f| File.basename(f["file"]) }
      expect(file_names).to include("syntax.exp")
      expect(file_names).to include("remark.exp")

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end
  end

  describe "#run with comprehensive entity detection" do
    let(:options) { { format: "json" } }
    let(:command) { described_class.new(options) }

    it "detects all major entity types" do
      command.run([sample_schema_path])

      # Check that JSON file was created
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      json_output = JSON.parse(File.read("coverage_report.json"))

      # Should detect a comprehensive set of entities
      expect(json_output["overall"]["total_entities"]).to be >= 300 # Should find many entities

      # Check that we have detailed reporting
      expect(json_output["files"]).not_to be_empty
      file_report = json_output["files"].first

      expect(file_report).to have_key("total")
      expect(file_report).to have_key("documented")
      expect(file_report).to have_key("coverage")
      expect(file_report["total"]).to be > 0

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end

    it "provides detailed undocumented entity information" do
      command.run([sample_schema_path])

      # Check that JSON file was created
      expect(output.string).to include("JSON coverage report written to: coverage_report.json")
      expect(File.exist?("coverage_report.json")).to be true

      json_output = JSON.parse(File.read("coverage_report.json"))

      if json_output["files"].any? && json_output["files"].first["undocumented"].any?
        undocumented_item = json_output["files"].first["undocumented"].first

        expect(undocumented_item).to have_key("type")
        expect(undocumented_item).to have_key("name")
        expect(undocumented_item["type"]).to be_a(String)
        expect(undocumented_item["name"]).to be_a(String)
      end

      # Clean up
      FileUtils.rm_f("coverage_report.json")
    end
  end

  describe "#run with yaml manifest" do
    # Create a minimal options hash
    let(:options) { { format: "text" } }
    # Create an instance of the command with test mode to prevent real exits
    let(:command) do
      cmd = described_class.new(options)
      # Enable test mode to prevent exit and raise an exception instead
      cmd.instance_variable_set(:@test_mode, true)
      cmd
    end

    # Set our test manifest file and make sure it has the proper paths
    # that are already relative to the manifest location
    before do
      # The test manifest uses paths already relative to its location
      # which matches the behavior we want
      unless File.exist?(test_manifest_path)
        File.write(test_manifest_path, {
          "schemas" => {
            "test_schema_1" => { "path" => "../syntax/remark.exp" },
            "test_schema_2" => { "path" => "../expressir/test_undocumented.exp" },
          },
        }.to_yaml)
      end
    end

    context "with a complex nested YAML manifest" do
      it "correctly processes schema files from nested paths",
         :aggregate_failures do
        # The private method is tested indirectly through the run method
        command.run([test_manifest_path])

        # Check that the output contains expected messages
        expect(output.string).to include("Processing schema manifest: #{test_manifest_path}")
        expect(output.string).to include("Found 2 schema files")
        expect(output.string).to include("Processing schemas from manifest file")

        # Check that it shows coverage info
        expect(output.string).to include("Documentation Coverage")
        expect(output.string).to include("remark.exp")
        expect(output.string).to include("Coverage Percentage")
      end

      it "creates a yaml report from the manifest" do
        # Reset the output for this test to capture just YAML output
        output.string = ""

        # Set format to yaml
        yaml_command = described_class.new(format: "yaml")

        # Run command
        yaml_command.run([test_manifest_path])

        # Check that YAML file was created
        expect(output.string).to include("YAML coverage report written to: coverage_report.yaml")
        expect(File.exist?("coverage_report.yaml")).to be true

        yaml_content = File.read("coverage_report.yaml")
        expect(yaml_content).to include("---")
        expect(yaml_content).to include("overall:")
        expect(yaml_content).to include("total_entities:")
        expect(yaml_content).to include("files:")
        expect(yaml_content).to include("file: spec/syntax/remark.exp")

        # Clean up
        FileUtils.rm_f("coverage_report.yaml")
      end

      it "creates a json report from the manifest" do
        # Reset the output for this test to capture just JSON output
        output.string = ""

        # Set format to json
        json_command = described_class.new(format: "json")

        # Run command
        json_command.run([test_manifest_path])

        # Check that JSON file was created
        expect(output.string).to include("JSON coverage report written to: coverage_report.json")
        expect(File.exist?("coverage_report.json")).to be true

        json_content = File.read("coverage_report.json")
        expect(json_content).to include("{")
        expect(json_content).to include("\"overall\":")
        expect(json_content).to include("\"total_entities\":")
        expect(json_content).to include("\"files\":")
        expect(json_content).to include("\"file\": \"spec/syntax/remark.exp\"")

        # Clean up
        FileUtils.rm_f("coverage_report.json")
      end
    end

    context "with an invalid YAML manifest" do
      # Use a temporary file for the invalid manifest
      let(:invalid_manifest_path) do
        File.join("spec", "fixtures", "invalid_manifest.yml")
      end

      before do
        # Create an invalid manifest file - valid YAML but wrong structure
        File.write(invalid_manifest_path,
                   "# Valid YAML but missing schemas key\nkey1: value1\nkey2: value2")
      end

      after do
        # Clean up the temporary file
        FileUtils.rm_f(invalid_manifest_path)
      end

      it "handles errors gracefully" do
        # The private method is tested indirectly through the run method
        expect do
          command.run([invalid_manifest_path])
        end.to raise_error(/No valid EXPRESS files were processed/)

        # Check that error messages were displayed
        expect(output.string).to include("Processing schema manifest: #{invalid_manifest_path}")
      end
    end
  end

  describe "error handling" do
    let(:options) { { format: "text" } }
    let(:command) { described_class.new(options) }

    it "handles non-existent files gracefully" do
      expect do
        command.run(["non_existent_file.exp"])
      end.to raise_error(Expressir::CommandError)
    end

    it "handles invalid file formats gracefully" do
      # Create a temporary invalid file
      invalid_file = "spec/fixtures/invalid.exp"
      File.write(invalid_file, "INVALID EXPRESS CONTENT")

      begin
        expect do
          command.run([invalid_file])
        end.to raise_error(Expressir::CommandError)
      ensure
        FileUtils.rm_f(invalid_file)
      end
    end
  end

  describe "FUNCTION:INNER exclusion" do
    let(:source) do
      <<~EXP
        SCHEMA inner_function_coverage_schema;
          FUNCTION outer_fn (outer_param : STRING): STRING;
            FUNCTION inner_fn (inner_param : STRING): STRING;
              RETURN (inner_param);
            END_FUNCTION;
            RETURN (inner_fn(outer_param));
          END_FUNCTION;
        END_SCHEMA;
      EXP
    end

    def entities_for(skip_types)
      repo = Expressir::Express::Parser.from_exp(source)
      schema = repo.schemas.first
      Expressir::Coverage.find_entities(schema, skip_types)
    end

    it "counts the inner function subtree without the exclusion" do
      ids = entities_for([]).map(&:id)

      expect(ids).to contain_exactly("outer_fn", "outer_param", "inner_fn", "inner_param")
    end

    it "excludes the inner function together with its parameters" do
      ids = entities_for(["FUNCTION:INNER"]).map(&:id)

      expect(ids).to contain_exactly("outer_fn", "outer_param")
    end
  end
end
