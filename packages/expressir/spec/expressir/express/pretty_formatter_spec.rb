require "spec_helper"

RSpec.describe Expressir::Express::PrettyFormatter do
  describe "Configuration" do
    describe "initialization with defaults" do
      let(:config) { described_class::Configuration.new }

      it "sets default indent to 4" do
        expect(config.indent).to eq(4)
      end

      it "sets default line_length to nil" do
        expect(config.line_length).to be_nil
      end

      it "sets default insert_newline to true" do
        expect(config.insert_newline).to be true
      end

      it "sets default insert_space to true" do
        expect(config.insert_space).to be true
      end

      it "sets default provenance_enabled to true" do
        expect(config.provenance_enabled).to be true
      end

      it "sets default provenance_name to 'Expressir'" do
        expect(config.provenance_name).to eq("Expressir")
      end

      it "sets default provenance_version to Expressir::Version::VERSION" do
        expect(config.provenance_version).to eq(Expressir::Version::VERSION)
      end
    end

    describe "initialization with options" do
      let(:options) do
        {
          indent: 2,
          line_length: 80,
          insert_newline: false,
          insert_space: false,
          provenance: false,
          provenance_name: "MyTool",
          provenance_version: "1.0.0",
        }
      end
      let(:config) { described_class::Configuration.new(options) }

      it "uses provided indent value" do
        expect(config.indent).to eq(2)
      end

      it "uses provided line_length value" do
        expect(config.line_length).to eq(80)
      end

      it "uses provided insert_newline value" do
        expect(config.insert_newline).to be false
      end

      it "uses provided insert_space value" do
        expect(config.insert_space).to be false
      end

      it "uses provided provenance value" do
        expect(config.provenance_enabled).to be false
      end

      it "uses provided provenance_name value" do
        expect(config.provenance_name).to eq("MyTool")
      end

      it "uses provided provenance_version value" do
        expect(config.provenance_version).to eq("1.0.0")
      end
    end

    describe "initialization with environment variables" do
      around do |example|
        # Save original ENV values
        original_env = {
          "EXPRESSIR_INDENT" => ENV.fetch("EXPRESSIR_INDENT", nil),
          "EXPRESSIR_LINE_LENGTH" => ENV.fetch("EXPRESSIR_LINE_LENGTH", nil),
          "EXPRESSIR_INSERT_NEWLINE" => ENV.fetch("EXPRESSIR_INSERT_NEWLINE",
                                                  nil),
          "EXPRESSIR_INSERT_SPACE" => ENV.fetch("EXPRESSIR_INSERT_SPACE", nil),
          "EXPRESSIR_PROVENANCE" => ENV.fetch("EXPRESSIR_PROVENANCE", nil),
          "EXPRESSIR_PROVENANCE_NAME" => ENV.fetch("EXPRESSIR_PROVENANCE_NAME",
                                                   nil),
          "EXPRESSIR_PROVENANCE_VERSION" => ENV.fetch(
            "EXPRESSIR_PROVENANCE_VERSION", nil
          ),
        }

        # Set test ENV values
        ENV["EXPRESSIR_INDENT"] = "8"
        ENV["EXPRESSIR_LINE_LENGTH"] = "120"
        ENV["EXPRESSIR_INSERT_NEWLINE"] = "false"
        ENV["EXPRESSIR_INSERT_SPACE"] = "false"
        ENV["EXPRESSIR_PROVENANCE"] = "false"
        ENV["EXPRESSIR_PROVENANCE_NAME"] = "EnvTool"
        ENV["EXPRESSIR_PROVENANCE_VERSION"] = "2.0.0"

        example.run

        # Restore original ENV values
        original_env.each do |key, value|
          if value.nil?
            ENV.delete(key)
          else
            ENV[key] = value
          end
        end
      end

      let(:config) { described_class::Configuration.new }

      it "reads indent from environment" do
        expect(config.indent).to eq(8)
      end

      it "reads line_length from environment" do
        expect(config.line_length).to eq(120)
      end

      it "reads insert_newline from environment" do
        expect(config.insert_newline).to be false
      end

      it "reads insert_space from environment" do
        expect(config.insert_space).to be false
      end

      it "reads provenance from environment" do
        expect(config.provenance_enabled).to be false
      end

      it "reads provenance_name from environment" do
        expect(config.provenance_name).to eq("EnvTool")
      end

      it "reads provenance_version from environment" do
        expect(config.provenance_version).to eq("2.0.0")
      end
    end

    describe "MECE hierarchy: Options > ENV > Defaults" do
      around do |example|
        original_indent = ENV.fetch("EXPRESSIR_INDENT", nil)
        ENV["EXPRESSIR_INDENT"] = "8"
        example.run
        if original_indent.nil?
          ENV.delete("EXPRESSIR_INDENT")
        else
          ENV["EXPRESSIR_INDENT"] = original_indent
        end
      end

      it "prioritizes option over environment variable" do
        config = described_class::Configuration.new(indent: 2)
        expect(config.indent).to eq(2)
      end

      it "uses environment variable when option not provided" do
        config = described_class::Configuration.new
        expect(config.indent).to eq(8)
      end
    end
  end

  describe "PrettyFormatter initialization" do
    it "creates a formatter with default configuration" do
      formatter = described_class.new
      expect(formatter.config).to be_a(described_class::Configuration)
      expect(formatter.config.indent).to eq(4)
    end

    it "creates a formatter with custom configuration" do
      formatter = described_class.new(indent: 2, line_length: 80)
      expect(formatter.config.indent).to eq(2)
      expect(formatter.config.line_length).to eq(80)
    end

    it "inherits from Formatter" do
      formatter = described_class.new
      expect(formatter).to be_a(Expressir::Express::Formatter)
    end

    it "passes no_remarks option to parent Formatter" do
      formatter = described_class.new(no_remarks: true)
      expect(formatter.no_remarks).to be true
    end
  end

  describe "#indent" do
    let(:formatter) { described_class.new(indent: 4) }

    it "indents a single line with configured width" do
      result = formatter.send(:indent, "test")
      expect(result).to eq("    test")
    end

    it "indents multiple lines with configured width" do
      result = formatter.send(:indent, "line1\nline2")
      expect(result).to eq("    line1\n    line2")
    end

    it "returns nil for nil input" do
      result = formatter.send(:indent, nil)
      expect(result).to be_nil
    end

    it "uses custom indent width" do
      custom_formatter = described_class.new(indent: 2)
      result = custom_formatter.send(:indent, "test")
      expect(result).to eq("  test")
    end
  end

  describe "#format_preamble_remark" do
    let(:formatter) { described_class.new }

    it "formats single-line remark" do
      remark = Expressir::Model::RemarkInfo.new(text: "This is a remark")
      result = formatter.send(:format_preamble_remark, remark)
      expect(result).to eq("(* This is a remark *)")
    end

    it "formats multi-line remark" do
      remark = Expressir::Model::RemarkInfo.new(text: "Line 1\nLine 2\nLine 3")
      result = formatter.send(:format_preamble_remark, remark)
      expect(result).to eq("(*\nLine 1\nLine 2\nLine 3\n*)")
    end
  end

  describe "#format_preamble" do
    let(:formatter) { described_class.new }

    it "returns empty array for nil remarks" do
      result = formatter.send(:format_preamble, nil)
      expect(result).to eq([])
    end

    it "returns empty array for empty remarks" do
      result = formatter.send(:format_preamble, [])
      expect(result).to eq([])
    end

    it "formats single remark with blank line" do
      remark = Expressir::Model::RemarkInfo.new(text: "Test remark")
      result = formatter.send(:format_preamble, [remark])
      expect(result).to eq(["(* Test remark *)", ""])
    end

    it "formats multiple remarks with blank line" do
      remark1 = Expressir::Model::RemarkInfo.new(text: "Remark 1")
      remark2 = Expressir::Model::RemarkInfo.new(text: "Remark 2")
      result = formatter.send(:format_preamble, [remark1, remark2])
      expect(result).to eq(["(* Remark 1 *)", "(* Remark 2 *)", ""])
    end
  end

  describe "#format_provenance" do
    it "generates provenance with default settings" do
      formatter = described_class.new
      result = formatter.send(:format_provenance)
      expect(result).to include("Generated by: Expressir version #{Expressir::Version::VERSION}")
      expect(result).to include("Format parameters: indent: 4")
      expect(result).to start_with("(*")
      expect(result).to end_with("*)")
    end

    it "includes line_length in provenance when set" do
      formatter = described_class.new(line_length: 80)
      result = formatter.send(:format_provenance)
      expect(result).to include("line_length: 80")
    end

    it "uses custom tool name and version" do
      formatter = described_class.new(
        provenance_name: "CustomTool",
        provenance_version: "2.0.0",
      )
      result = formatter.send(:format_provenance)
      expect(result).to include("Generated by: CustomTool version 2.0.0")
    end

    it "returns nil when provenance is disabled" do
      formatter = described_class.new(provenance: false)
      result = formatter.send(:format_provenance)
      expect(result).to be_nil
    end
  end

  describe "#format_repository" do
    let(:formatter) { described_class.new }
    let(:schema) do
      Expressir::Model::Declarations::Schema.new(
        id: "test_schema",
        entities: [],
        types: [],
      )
    end
    let(:repository) do
      Expressir::Model::Repository.new(schemas: [schema])
    end

    it "formats repository with provenance" do
      result = formatter.send(:format_repository, repository)
      expect(result).to include("Generated by: Expressir")
      expect(result).to include("SCHEMA test_schema")
      expect(result).to include("END_SCHEMA")
    end

    it "includes preamble when untagged_remarks present" do
      repo_with_remarks = Expressir::Model::Repository.new(
        schemas: [schema],
        untagged_remarks: [Expressir::Model::RemarkInfo.new(text: "Test preamble")],
      )

      result = formatter.send(:format_repository, repo_with_remarks)
      expect(result).to include("Test preamble")
      expect(result).to include("Generated by: Expressir")
      expect(result).to include("SCHEMA test_schema")
    end

    it "does not include provenance when disabled" do
      no_prov_formatter = described_class.new(provenance: false)

      result = no_prov_formatter.send(:format_repository, repository)
      expect(result).not_to include("Generated by:")
      expect(result).to include("SCHEMA test_schema")
    end
  end

  describe "#format_constant_block" do
    let(:formatter) { described_class.new }

    it "returns empty string for nil constants" do
      result = formatter.send(:format_constant_block, nil)
      expect(result).to eq("")
    end

    it "returns empty string for empty constants" do
      result = formatter.send(:format_constant_block, [])
      expect(result).to eq("")
    end

    it "formats single constant" do
      # Create real constant object with INTEGER type
      int_type = Expressir::Model::DataTypes::Integer.new
      Expressir::Model::References::SimpleReference.new(id: "INTEGER")
      constant = Expressir::Model::Declarations::Constant.new(
        id: "const1",
        type: int_type,
        expression: Expressir::Model::Literals::Integer.new(value: 42),
      )

      # Stub the format method to return the expected strings
      allow(formatter).to receive(:format).with(int_type).and_return("INTEGER")
      allow(formatter).to receive(:format).with(constant.expression).and_return("42")

      result = formatter.send(:format_constant_block, [constant])
      expect(result).to eq("const1 : INTEGER := 42;")
    end

    it "aligns multiple constants with different name lengths" do
      int_type = Expressir::Model::DataTypes::Integer.new
      string_type = Expressir::Model::DataTypes::String.new

      const1 = Expressir::Model::Declarations::Constant.new(
        id: "a",
        type: int_type,
        expression: Expressir::Model::Literals::Integer.new(value: 1),
      )
      const2 = Expressir::Model::Declarations::Constant.new(
        id: "longer_name",
        type: string_type,
        expression: Expressir::Model::Literals::String.new(value: "test"),
      )

      allow(formatter).to receive(:format).with(int_type).and_return("INTEGER")
      allow(formatter).to receive(:format).with(string_type).and_return("STRING")
      allow(formatter).to receive(:format).with(const1.expression).and_return("1")
      allow(formatter).to receive(:format).with(const2.expression).and_return("'test'")

      result = formatter.send(:format_constant_block, [const1, const2])
      lines = result.split("\n")

      expect(lines.length).to eq(2)
      expect(lines[0]).to eq("a           : INTEGER := 1;")
      expect(lines[1]).to eq("longer_name : STRING  := 'test';")

      # Verify alignment - colons should be at the same position
      colon_pos_1 = lines[0].index(":")
      colon_pos_2 = lines[1].index(":")
      expect(colon_pos_1).to eq(colon_pos_2)

      # Verify alignment - assignment operators should be at the same position
      assign_pos_1 = lines[0].index(":=")
      assign_pos_2 = lines[1].index(":=")
      expect(assign_pos_1).to eq(assign_pos_2)
    end

    it "aligns constants with different type lengths" do
      type1 = Expressir::Model::DataTypes::Integer.new
      type2 = Expressir::Model::DataTypes::String.new

      const1 = Expressir::Model::Declarations::Constant.new(
        id: "name1",
        type: type1,
        expression: Expressir::Model::Literals::Integer.new(value: 1),
      )
      const2 = Expressir::Model::Declarations::Constant.new(
        id: "name2",
        type: type2,
        expression: Expressir::Model::Literals::Integer.new(value: 2),
      )

      allow(formatter).to receive(:format).with(type1).and_return("INT")
      allow(formatter).to receive(:format).with(type2).and_return("VERY_LONG_TYPE_NAME")
      allow(formatter).to receive(:format).with(const1.expression).and_return("1")
      allow(formatter).to receive(:format).with(const2.expression).and_return("2")

      result = formatter.send(:format_constant_block, [const1, const2])
      lines = result.split("\n")

      # Verify assignment operators are aligned
      assign_pos_1 = lines[0].index(":=")
      assign_pos_2 = lines[1].index(":=")
      expect(assign_pos_1).to eq(assign_pos_2)
    end
  end
end
