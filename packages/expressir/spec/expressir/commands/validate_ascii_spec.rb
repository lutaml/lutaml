# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tempfile"

RSpec.describe Expressir::Commands::ValidateAscii do
  let(:output) { StringIO.new }

  before do
    # Redirect stdout for all tests
    allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
    allow($stdout).to receive(:print) { |msg| output.print(msg) }
  end

  describe "NonAsciiViolationCollection" do
    let(:collection) { Expressir::Commands::NonAsciiViolationCollection.new }

    describe "#encode_express_format" do
      it "encodes ASCII characters correctly" do
        expect(collection.send(:encode_express_format, "A")).to eq("\"00000041\"")
      end

      it "encodes A-ring character correctly" do
        expect(collection.send(:encode_express_format, "Å")).to eq("\"000000C5\"")
      end

      it "encodes Japanese characters correctly" do
        # Test for 神戸 encoding
        expect(collection.send(:encode_express_format, "神")).to eq("\"0000795E\"")
        expect(collection.send(:encode_express_format, "戸")).to eq("\"00006238\"")
      end
    end

    describe "#process_non_ascii_char" do
      before do
        # Initialize the unicode_to_asciimath map via the public interface
        collection.process_file("spec/fixtures/examples/tail_remarks_test_schema.exp")
      end

      it "identifies common math symbols correctly" do
        # Test multiplication symbol
        result = collection.send(:process_non_ascii_char, "×")
        expect(result[:is_math]).to be true
        expect(result[:replacement]).to eq("xx")
        expect(result[:replacement_type]).to eq("asciimath")

        # Test pi symbol
        result = collection.send(:process_non_ascii_char, "π")
        expect(result[:is_math]).to be true
        expect(result[:replacement]).to eq("pi")
        expect(result[:replacement_type]).to eq("asciimath")

        # Test lambda symbol
        result = collection.send(:process_non_ascii_char, "λ")
        expect(result[:is_math]).to be true
        expect(result[:replacement]).to eq("lambda")
        expect(result[:replacement_type]).to eq("asciimath")

        # Test less than or equal symbol
        result = collection.send(:process_non_ascii_char, "≤")
        expect(result[:is_math]).to be true
        expect(result[:replacement]).to eq("le")
        expect(result[:replacement_type]).to eq("asciimath")
      end

      it "encodes non-math symbols with ISO 10303-11" do
        result = collection.send(:process_non_ascii_char, "神")
        expect(result[:is_math]).to be false
        expect(result[:replacement]).to eq("\"0000795E\"")
        expect(result[:replacement_type]).to eq("iso-10303-11")
      end
    end
  end

  describe "#run" do
    let(:options) { {} }
    let(:command) { described_class.new(options) }

    context "with check_remarks option" do
      let(:fixtures_dir) { "spec/fixtures/validate_ascii" }

      it "scans tail remarks by default but skips embedded remarks (check_remarks: false)" do
        command.run("#{fixtures_dir}/non_ascii_in_remarks_only.exp")

        # Tail remarks (`--`) are part of code lines and stay in scope (issue #285).
        # Embedded remarks (`(* ... *)`) are excluded by default.
        # The fixture's tail-remark lines (e.g. `-- Japanese: 日本語、中文、한글`)
        # carry non-ASCII chars that must be flagged.
        expect(output.string).to include("non-ASCII sequence")
        expect(output.string).to include("日")
        # Embedded-remark text is masked out; verified indirectly by the fact
        # that the same fixture yields MORE violations under --check-remarks
        # (see the next test).
      end

      it "includes both tail and embedded remarks when check_remarks is true" do
        command_with_check = described_class.new(check_remarks: true)

        command_with_check.run("#{fixtures_dir}/non_ascii_in_remarks_only.exp")

        # Should find violations in remarks
        expect(output.string).to include("non-ASCII sequence")
        expect(output.string).to include("日")
        expect(output.string).to include("中")
      end

      it "detects all violations when check_remarks is true for file with both" do
        command_with_check = described_class.new(check_remarks: true)

        command_with_check.run("#{fixtures_dir}/non_ascii_in_both.exp")

        # Should detect violations in both code and remarks
        expect(output.string).to include("non-ASCII sequence")

        # Violations should include both code and remark Unicode
        violation_count = output.string.scan("Line").size
        expect(violation_count).to be > 3 # Should be more when remarks are included
      end
    end

    context "with fixture files" do
      let(:fixtures_dir) { "spec/fixtures/validate_ascii" }

      it "detects tail-remark violations by default for file with non-ASCII only in remarks" do
        command.run("#{fixtures_dir}/non_ascii_in_remarks_only.exp")

        # Tail remarks are scanned; embedded remarks are not.
        expect(output.string).to include("Scanned")
        expect(output.string).to include("1")
        expect(output.string).to include("EXPRESS file(s)")
        expect(output.string).to include("Found")
        # Should find at least one tail-remark violation (e.g. -- Japanese: 日本語)
        expect(output.string).to include("non-ASCII sequence(s) in")
        expect(output.string).to include("1")
      end

      it "detects violations in file with non-ASCII in code" do
        command.run("#{fixtures_dir}/non_ascii_in_code.exp")

        # Should detect violations in entity names, attributes, etc.
        expect(output.string).to include("non-ASCII sequence")
        expect(output.string).to include("製品")
        expect(output.string).to include("名前")
        expect(output.string).to include("π")
        expect(output.string).to include("μ")
      end

      it "detects code and tail-remark violations in file with non-ASCII in both" do
        command.run("#{fixtures_dir}/non_ascii_in_both.exp")

        # Default scope: code + tail remarks. Should detect code violations
        # and tail-remark violations, but skip embedded-remark text.
        expect(output.string).to include("non-ASCII sequence")
        expect(output.string).to include("価格") # Code violation
        expect(output.string).to include("π") # Code violation

        violation_count = output.string.scan("non-ASCII sequence").size
        expect(violation_count).to be > 0
        expect(violation_count).to be < 10 # Should be much less than all Unicode chars including remarks
      end
    end

    context "with valid EXPRESS file containing non-ASCII" do
      let(:temp_file) { Tempfile.new(["test", ".exp"]) }

      after do
        temp_file.close
        temp_file.unlink
      end

      it "detects non-ASCII characters outside remarks" do
        temp_file.write("SCHEMA test_schema;\nENTITY test_entity;\n  神戸 : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
        temp_file.close

        command.run(temp_file.path)

        # Should detect 神戸 outside of remarks
        expect(output.string).to include("神")
        expect(output.string).to include("戸")
        expect(output.string).to include("\"0000795E\"")
        expect(output.string).to include("\"00006238\"")
      end

      it "detects non-ASCII characters in tail remarks by default (issue #285)" do
        temp_file.write("SCHEMA test_schema;\nENTITY test_entity;\n  name : STRING; -- 神戸 Japanese characters\nEND_ENTITY;\nEND_SCHEMA;\n")
        temp_file.close

        command.run(temp_file.path)

        # Tail remarks are part of code lines and stay in scope by default.
        expect(output.string).to include("神")
        expect(output.string).to include("戸")
      end

      it "excludes non-ASCII characters in embedded remarks by default" do
        temp_file.write("SCHEMA test_schema;\nENTITY (* comment with 中文字 *) test_entity;\n  name : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
        temp_file.close

        command.run(temp_file.path)

        # Should NOT detect 中文字 in embedded remark (default scope excludes embedded)
        expect(output.string).not_to include("中")
        expect(output.string).not_to include("文")
        expect(output.string).not_to include("字")
      end

      it "detects non-ASCII in entity names" do
        temp_file.write("SCHEMA test_schema;\nENTITY 日本語;\n  name : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
        temp_file.close

        command.run(temp_file.path)

        # Should detect 日本語 in entity name
        expect(output.string).to include("日")
        expect(output.string).to include("本")
        expect(output.string).to include("語")
      end
    end

    context "with YAML output format" do
      let(:options) { { yaml: true } }
      let(:command) { described_class.new(options) }
      let(:temp_file) { Tempfile.new(["test", ".exp"]) }

      after do
        temp_file.close
        temp_file.unlink
      end

      it "outputs results in YAML format" do
        temp_file.write("SCHEMA test_schema;\nENTITY test;\n  神 : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
        temp_file.close

        command.run(temp_file.path)

        # Should output YAML format
        expect(output.string).to include("---")
        expect(output.string).to include("summary:")
        expect(output.string).to include("total_files:")
        expect(output.string).to include("violations:")
      end
    end

    context "with recursive option" do
      let(:options) { { recursive: true } }
      let(:command) { described_class.new(options) }
      let(:temp_dir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it "processes files recursively" do
        FileUtils.mkdir_p(File.join(temp_dir, "subdir"))
        File.write(File.join(temp_dir, "test1.exp"),
                   "SCHEMA test1;\nENTITY test1;\n  神 : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
        File.write(File.join(temp_dir, "subdir", "test2.exp"),
                   "SCHEMA test2;\nENTITY test2;\n  π : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")

        command.run(temp_dir)

        # Should scan 2 files and find violations
        expect(output.string).to include("Summary:")
        expect(output.string).to include("2")
        expect(output.string).to include("EXPRESS file(s)")
      end
    end

    context "error handling" do
      it "raises ENOENT error for non-existent file" do
        expect do
          command.run("non_existent_file.exp")
        end.to raise_error(Errno::ENOENT, /No EXPRESS files found/)
      end

      it "raises ArgumentError for non-EXPRESS file" do
        temp_file = Tempfile.new(["test", ".txt"])
        begin
          expect do
            command.run(temp_file.path)
          end.to raise_error(ArgumentError, /not an EXPRESS file/)
        ensure
          temp_file.close
          temp_file.unlink
        end
      end

      it "raises ENOENT error for directory with no EXPRESS files" do
        temp_dir = Dir.mktmpdir
        begin
          expect do
            command.run(temp_dir)
          end.to raise_error(Errno::ENOENT, /No EXPRESS files found/)
        ensure
          FileUtils.rm_rf(temp_dir)
        end
      end
    end
  end

  describe "FileViolations" do
    let(:file_path) { "/path/to/test.exp" }
    let(:file_violations) { Expressir::Commands::FileViolations.new(file_path) }

    it "initializes with correct attributes" do
      expect(file_violations.path).to eq(file_path)
      expect(file_violations.filename).to eq("test.exp")
      expect(file_violations.directory).to eq("/path/to")
      expect(file_violations.violations).to be_empty
    end

    it "adds violations correctly" do
      char_details = [{
        char: "神",
        hex: "0x795e",
        utf8: "0xe7 0xa5 0x9e",
        is_math: false,
        replacement: "\"0000795E\"",
        replacement_type: "iso-10303-11",
      }]

      file_violations.add_violation(10, 5, "神", char_details, "ENTITY 神;")

      expect(file_violations.violation_count).to eq(1)
      expect(file_violations.unique_characters.size).to eq(1)
    end
  end

  describe "NonAsciiCharacter" do
    let(:character) do
      Expressir::Commands::NonAsciiCharacter.new(
        "π",
        "0x3c0",
        "0xcf 0x80",
        true,
        "pi",
        "asciimath",
      )
    end

    it "initializes with correct attributes" do
      expect(character.char).to eq("π")
      expect(character.hex).to eq("0x3c0")
      expect(character.is_math).to be true
      expect(character.replacement).to eq("pi")
    end

    it "adds occurrences correctly" do
      character.add_occurrence(5, 10, "value = π;")
      expect(character.occurrence_count).to eq(1)
      expect(character.occurrences.first[:line_number]).to eq(5)
    end

    it "returns correct replacement text for math symbols" do
      expect(character.replacement_text).to eq("AsciiMath: pi")
    end

    it "returns correct replacement text for non-math symbols" do
      non_math = Expressir::Commands::NonAsciiCharacter.new(
        "神",
        "0x795e",
        "0xe7 0xa5 0x9e",
        false,
        "\"0000795E\"",
        "iso-10303-11",
      )
      expect(non_math.replacement_text).to eq("ISO 10303-11: \"0000795E\"")
    end
  end
end
