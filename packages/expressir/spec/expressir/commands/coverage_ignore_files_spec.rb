require "spec_helper"
require "tempfile"
require "yaml"

RSpec.describe Expressir::Commands::Coverage do
  let(:command) { described_class.new({}) }
  let(:test_schema_path) do
    "spec/fixtures/examples/nested_functions_test_schema.exp"
  end

  describe "ignore files functionality" do
    let(:temp_ignore_file) { Tempfile.new(["ignore_files", ".yaml"]) }

    after do
      temp_ignore_file.close
      temp_ignore_file.unlink
    end

    context "with valid ignore files YAML" do
      before do
        # Use absolute paths to ensure they match
        base_dir = File.expand_path("spec/fixtures/examples", Dir.pwd)
        ignore_patterns = [
          File.join(base_dir, "nested_functions_test_schema.exp"),
          File.join(base_dir, "*_test_*.exp"),
        ]
        temp_ignore_file.write(ignore_patterns.to_yaml)
        temp_ignore_file.rewind
      end

      it "excludes files matching ignore patterns from overall statistics" do
        command_with_ignore = described_class.new({ ignore_files: temp_ignore_file.path })

        # Capture output to avoid cluttering test output
        allow(command_with_ignore).to receive(:say)

        reports = command_with_ignore.send(:collect_reports,
                                           ["spec/fixtures/examples/"])
        structured_report = command_with_ignore.send(:build_structured_report,
                                                     reports)

        # Should have ignored files information
        expect(structured_report["overall"]["ignored_files_count"]).to be > 0
        expect(structured_report["overall"]["ignored_entities_count"]).to be > 0
        expect(structured_report["ignored_files"]).not_to be_nil

        # Check that ignored files are marked correctly
        ignored_files = structured_report["ignored_files"]
        expect(ignored_files).to be_an(Array)
        expect(ignored_files.size).to be > 0

        # Verify nested_functions_test_schema.exp is in ignored files
        nested_file = ignored_files.find do |f|
          f["file_basename"] == "nested_functions_test_schema.exp"
        end
        expect(nested_file).not_to be_nil
        expect(nested_file["ignored"]).to be_nil # ignored files section doesn't need this flag
        expect(nested_file["matched_pattern"]).not_to be_nil
      end

      it "includes ignored files in the files section with ignored flag" do
        command_with_ignore = described_class.new({ ignore_files: temp_ignore_file.path })

        # Capture output to avoid cluttering test output
        allow(command_with_ignore).to receive(:say)

        reports = command_with_ignore.send(:collect_reports,
                                           ["spec/fixtures/examples/"])
        structured_report = command_with_ignore.send(:build_structured_report,
                                                     reports)

        # Check files section includes ignored files with flag
        files = structured_report["files"]
        nested_file = files.find do |f|
          f["file_basename"] == "nested_functions_test_schema.exp"
        end

        expect(nested_file).not_to be_nil
        expect(nested_file["ignored"]).to be true
        expect(nested_file["matched_pattern"]).not_to be_nil
      end
    end

    context "with non-existent ignore files YAML" do
      it "handles missing ignore files gracefully" do
        command_with_ignore = described_class.new({ ignore_files: "/non/existent/file.yaml" })

        # Should not raise an error and should return empty hash
        result = command_with_ignore.send(:parse_ignore_files)
        expect(result).to eq({})
      end
    end

    context "with invalid ignore files YAML format" do
      before do
        temp_ignore_file.write("invalid: yaml: format: not: an: array")
        temp_ignore_file.rewind
      end

      it "handles invalid YAML format gracefully" do
        command_with_ignore = described_class.new({ ignore_files: temp_ignore_file.path })

        # Should not raise an error and should return empty hash
        result = command_with_ignore.send(:parse_ignore_files)
        expect(result).to eq({})
      end
    end

    context "with patterns that don't match any files" do
      before do
        ignore_patterns = ["non/existent/pattern/*.exp"]
        temp_ignore_file.write(ignore_patterns.to_yaml)
        temp_ignore_file.rewind
      end

      it "handles non-matching patterns gracefully" do
        command_with_ignore = described_class.new({ ignore_files: temp_ignore_file.path })

        # Capture warning output
        allow(command_with_ignore).to receive(:say)

        result = command_with_ignore.send(:parse_ignore_files)
        expect(result).to eq({})
      end
    end
  end

  describe "FUNCTION:INNER exclusion functionality" do
    it "excludes inner functions from coverage when FUNCTION:INNER is specified" do
      command_with_exclusion = described_class.new({ exclude: "FUNCTION:INNER" })

      # Capture output to avoid cluttering test output
      allow(command_with_exclusion).to receive(:say)

      reports = command_with_exclusion.send(:collect_reports,
                                            [test_schema_path])
      report = reports.first

      # Should have fewer entities when inner functions are excluded
      expect(report.total_entities.size).to eq(5) # Only top-level entities

      # Verify that inner functions are not included
      entity_names = report.total_entities.map(&:id).map(&:to_s)
      expect(entity_names).to include("top_level_function")
      expect(entity_names).to include("another_top_level_function")
      expect(entity_names).not_to include("inner_function_in_function")
      expect(entity_names).not_to include("deeply_nested_function")
      expect(entity_names).not_to include("inner_function_in_rule")
      expect(entity_names).not_to include("inner_function_in_procedure")
      expect(entity_names).not_to include("nested_in_procedure_function")
    end

    it "includes all functions when FUNCTION:INNER is not specified" do
      command_without_exclusion = described_class.new({})

      # Capture output to avoid cluttering test output
      allow(command_without_exclusion).to receive(:say)

      reports = command_without_exclusion.send(:collect_reports,
                                               [test_schema_path])
      report = reports.first

      # Should have all entities including inner functions
      expect(report.total_entities.size).to eq(10) # All entities

      # Verify that inner functions are included
      entity_names = report.total_entities.map(&:id).map(&:to_s)
      expect(entity_names).to include("inner_function_in_function")
      expect(entity_names).to include("deeply_nested_function")
      expect(entity_names).to include("inner_function_in_rule")
      expect(entity_names).to include("inner_function_in_procedure")
      expect(entity_names).to include("nested_in_procedure_function")
    end
  end

  describe "combined functionality" do
    let(:temp_ignore_file) { Tempfile.new(["ignore_files", ".yaml"]) }

    after do
      temp_ignore_file.close
      temp_ignore_file.unlink
    end

    it "works correctly when both ignore files and FUNCTION:INNER exclusion are used" do
      # Create ignore file that doesn't match our test schema
      ignore_patterns = ["examples/some_other_file.exp"]
      temp_ignore_file.write(ignore_patterns.to_yaml)
      temp_ignore_file.rewind

      command_with_both = described_class.new({
                                                exclude: "FUNCTION:INNER",
                                                ignore_files: temp_ignore_file.path,
                                              })

      # Capture output to avoid cluttering test output
      allow(command_with_both).to receive(:say)

      reports = command_with_both.send(:collect_reports, [test_schema_path])
      report = reports.first

      # Should exclude inner functions but not ignore the file (since pattern doesn't match)
      expect(report.total_entities.size).to eq(5) # Only top-level entities

      # File should not be ignored
      structured_report = command_with_both.send(:build_structured_report,
                                                 reports)
      files = structured_report["files"]
      test_file = files.find do |f|
        f["file_basename"] == "nested_functions_test_schema.exp"
      end
      expect(test_file["ignored"]).to be false
    end
  end
end
