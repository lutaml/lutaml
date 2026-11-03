# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "lutaml/lml/cli"

RSpec.describe Lutaml::Lml::Diagnostic do
  def write(dir, name, content)
    path = File.join(dir, name)
    File.write(path, content)
    path
  end

  def parse_file(path)
    File.open(path) { |file| Lutaml::Lml.parse_document(file) }
  end

  describe "the code registry" do
    it "covers every validator rule" do
      expect(Lutaml::Lml::Validator::RULE_CODES.values - described_class::CODES.keys)
        .to be_empty
    end

    it "defaults severity and remedy from the registry" do
      diagnostic = described_class.build('parse/LML-001', message: 'boom')

      expect(diagnostic.severity).to eq('error')
      expect(diagnostic.remedy).to eq('Fix the syntax at the reported position.')
    end

    it "is documented in the README" do
      readme = File.read(File.expand_path("../../../../../docs/lml.adoc", __dir__))

      described_class::CODES.each_key do |code|
        expect(readme).to include("`#{code}`")
      end
    end
  end

  describe "rendering" do
    it "renders path, position, code, message, and remedy" do
      diagnostic = described_class.build(
        'validation/LML-V01', message: "'Tile' is defined twice",
                              file: 'model.lml', line: 3, column: 7
      )

      expect(diagnostic.to_s).to eq(<<~TEXT.chomp)
        model.lml:3:7: [validation/LML-V01] 'Tile' is defined twice
          remedy: Rename or remove the duplicate definition.
      TEXT
    end

    it "omits absent position segments" do
      diagnostic = described_class.build('contract/LML-C01', message: 'File does not exist')

      expect(diagnostic.to_s).to start_with('[contract/LML-C01] File does not exist')
    end
  end

  describe "parse failures" do
    it "carries a positioned diagnostic" do
      Dir.mktmpdir do |dir|
        path = write(dir, "bad.lml", "class A {\n")

        expect { parse_file(path) }.to raise_error(Lutaml::Lml::ParsingError) do |error|
          diagnostic = error.diagnostic

          expect(diagnostic.code).to eq('parse/LML-001')
          expect(diagnostic.file).to eq(path)
          expect(diagnostic.line).to eq(1)
          expect(diagnostic.column).to eq(10)
        end
      end
    end

    it "keeps the human message unchanged" do
      Dir.mktmpdir do |dir|
        path = write(dir, "bad.lml", "class A {\n")

        # parsanol's phrasing may evolve (it reworded EOF failures in
        # 1.3.99); the invariant is that the position stays in the text.
        expect { parse_file(path) }.to raise_error(Lutaml::Lml::ParsingError, /at line 1 char 10\./)
      end
    end
  end

  describe "preprocessor failures" do
    it "reports an unterminated block comment with its position" do
      Dir.mktmpdir do |dir|
        path = write(dir, "comment.lml", "class A {\n/* open\n}\n")

        expect { parse_file(path) }.to raise_error(Lutaml::Lml::Error) do |error|
          expect(error.diagnostic.code).to eq('parse/LML-002')
          expect(error.diagnostic.line).to eq(2)
          expect(error.diagnostic.column).to eq(1)
        end
      end
    end

    it "reports a missing include at the include line" do
      Dir.mktmpdir do |dir|
        path = write(dir, "main.lml", "class A { }\ninclude missing.lml\n")

        expect { parse_file(path) }.to raise_error(Lutaml::Lml::Error) do |error|
          expect(error.diagnostic.code).to eq('parse/LML-003')
          expect(error.diagnostic.line).to eq(2)
        end
      end
    end

    it "reports a circular include at the offending line" do
      Dir.mktmpdir do |dir|
        write(dir, "a.lml", "include b.lml\n")
        path = write(dir, "b.lml", "include a.lml\n")

        expect { parse_file(path) }.to raise_error(Lutaml::Lml::Error) do |error|
          expect(error.diagnostic.code).to eq('parse/LML-003')
          expect(error.diagnostic.message).to include('circular include')
          expect(error.diagnostic.file).to eq(path)
        end
      end
    end
  end

  describe "validation diagnostics" do
    it "cites the offending definition position" do
      Dir.mktmpdir do |dir|
        path = write(dir, "dup.lml", "class Tile { }\nclass Tile { }\n")
        diagnostic = Lutaml::Lml::Validator.diagnostics(parse_file(path)).first

        expect(diagnostic.code).to eq('validation/LML-V01')
        expect(diagnostic.file).to eq(path)
        expect(diagnostic.line).to eq(1)
        expect(diagnostic.column).to eq(7)
      end
    end

    it "cites the instance attribute for a value violation" do
      source = <<~LML
        class Glaze { attribute code, String { pattern /\\A[A-Z]+\\z/ } }

        instances {
          instance "g" Glaze {
            code = "lower"
          }
        }
      LML
      diagnostic = Lutaml::Lml::Validator.diagnostics(Lutaml::Lml.parse_document(source)).first

      expect(diagnostic.code).to eq('validation/LML-V09')
      expect(diagnostic.line).to eq(5)
    end

    it "reports an uncompilable pattern against the attribute" do
      source = <<~LML
        class Glaze { attribute code, String { pattern /[/ } }

        instances {
          instance "g" Glaze {
            code = "x"
          }
        }
      LML

      diagnostics = Lutaml::Lml::Validator.diagnostics(Lutaml::Lml.parse_document(source))

      expect(diagnostics.map(&:code)).to eq(['validation/LML-V10'])
    end
  end

  describe "CLI JSON output" do
    def run_validate(*args)
      output = StringIO.new
      original = $stdout
      $stdout = output
      begin
        Lutaml::Cli::LmlCommands.start(["validate", *args])
      rescue SystemExit => e
        return [output.string, e.status]
      ensure
        $stdout = original
      end
      [output.string, 0]
    end

    it "emits the diagnostic array and exits 1" do
      Dir.mktmpdir do |dir|
        path = write(dir, "dup.lml", "class Tile { }\nclass Tile { }\n")
        output, status = run_validate(path, "--format", "json")
        payload = JSON.parse(output)

        expect(status).to eq(1)
        expect(payload).to contain_exactly(
          include(
            "code" => "validation/LML-V01",
            "severity" => "error",
            "file" => path,
            "line" => 1,
            "column" => 7,
          ),
        )
      end
    end

    it "emits an empty array for a valid file and exits 0" do
      Dir.mktmpdir do |dir|
        path = write(dir, "ok.lml", "class Tile { }\n")
        output, status = run_validate(path, "--format", "json")

        expect(status).to eq(0)
        expect(JSON.parse(output)).to eq([])
      end
    end

    it "renders text with position and code by default" do
      Dir.mktmpdir do |dir|
        path = write(dir, "dup.lml", "class Tile { }\nclass Tile { }\n")
        output, status = run_validate(path)

        expect(status).to eq(1)
        expect(output).to include("#{path}:1:7: [validation/LML-V01]")
        expect(output).to include("remedy:")
      end
    end
  end
end
