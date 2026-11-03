# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/output_strategy"

RSpec.describe Lutaml::Xsd::Spa::OutputStrategy do
  # Concrete implementation for testing abstract base class
  let(:concrete_strategy_class) do
    Class.new(described_class) do
      attr_reader :files_written

      def initialize(verbose: false)
        super
        @files_written = []
      end

      protected

      def write_files(_html_content, _schema_data)
        @files_written = ["/tmp/test.html"]
      end
    end
  end

  subject(:strategy) { concrete_strategy_class.new }

  describe "#initialize" do
    it "accepts verbose option" do
      strategy = concrete_strategy_class.new(verbose: true)
      expect(strategy.verbose).to be true
    end

    it "defaults verbose to false" do
      strategy = concrete_strategy_class.new
      expect(strategy.verbose).to be false
    end
  end

  describe "#write" do
    let(:html_content) { "<html><body>Test</body></html>" }
    let(:schema_data) { { metadata: {}, schemas: [] } }

    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)
    end

    it "calls prepare_output" do
      expect(strategy).to receive(:prepare_output)
      strategy.write(html_content, schema_data)
    end

    it "calls write_files" do
      expect(strategy).to receive(:write_files).with(html_content,
                                                     schema_data).and_call_original
      strategy.write(html_content, schema_data)
    end

    it "calls verify_files" do
      expect(strategy).to receive(:verify_files).and_call_original
      strategy.write(html_content, schema_data)
    end

    it "returns list of written files" do
      result = strategy.write(html_content, schema_data)
      expect(result).to eq(["/tmp/test.html"])
    end

    context "when verbose mode enabled" do
      subject(:strategy) { concrete_strategy_class.new(verbose: true) }

      it "logs preparation message" do
        expect do
          strategy.write(html_content, schema_data)
        end.to output(/Preparing output/).to_stdout
      end

      it "logs success message" do
        expect do
          strategy.write(html_content, schema_data)
        end.to output(/Successfully wrote 1 file/).to_stdout
      end
    end

    context "when verbose mode disabled" do
      it "does not log messages" do
        expect do
          strategy.write(html_content, schema_data)
        end.not_to output.to_stdout
      end
    end
  end

  describe "#write_files" do
    it "raises NotImplementedError in base class" do
      base_strategy = described_class.new

      expect do
        base_strategy.send(:write_files, "", {})
      end.to raise_error(NotImplementedError, /must implement #write_files/)
    end
  end

  describe "#prepare_output" do
    it "has default implementation that does nothing" do
      expect { strategy.send(:prepare_output) }.not_to raise_error
    end
  end

  describe "#verify_files" do
    context "when all files exist and are not empty" do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(100)
      end

      it "does not raise error" do
        expect do
          strategy.send(:verify_files, ["/tmp/test.html"])
        end.not_to raise_error
      end
    end

    context "when file does not exist" do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it "raises IOError" do
        expect do
          strategy.send(:verify_files, ["/tmp/missing.html"])
        end.to raise_error(IOError, /Failed to write file/)
      end
    end

    context "when file is empty" do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(0)
        allow(File).to receive(:empty?).and_return(true)
      end

      it "raises IOError" do
        expect do
          strategy.send(:verify_files, ["/tmp/empty.html"])
        end.to raise_error(IOError, /File is empty/)
      end
    end

    context "when multiple files" do
      it "verifies all files" do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:size).and_return(100)

        expect do
          strategy.send(:verify_files, ["/tmp/file1.html", "/tmp/file2.html"])
        end.not_to raise_error
      end
    end
  end

  describe "#ensure_directory" do
    context "when directory exists" do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
      end

      it "does not create directory" do
        expect(FileUtils).not_to receive(:mkdir_p)
        strategy.send(:ensure_directory, "/tmp/existing")
      end
    end

    context "when directory does not exist" do
      before do
        allow(Dir).to receive(:exist?).and_return(false)
      end

      it "creates directory" do
        expect(FileUtils).to receive(:mkdir_p).with("/tmp/new")
        strategy.send(:ensure_directory, "/tmp/new")
      end

      context "when verbose mode enabled" do
        subject(:strategy) { concrete_strategy_class.new(verbose: true) }

        it "logs directory creation" do
          allow(FileUtils).to receive(:mkdir_p)

          expect do
            strategy.send(:ensure_directory, "/tmp/new")
          end.to output(/Created directory:.*new/).to_stdout
        end
      end
    end
  end

  describe "#write_file" do
    let(:path) { "/tmp/test.html" }
    let(:content) { "<html>Test</html>" }

    it "writes content to file" do
      expect(File).to receive(:write).with(path, content)
      strategy.send(:write_file, path, content)
    end

    it "returns file path" do
      allow(File).to receive(:write)
      result = strategy.send(:write_file, path, content)

      expect(result).to eq(path)
    end

    context "when verbose mode enabled" do
      subject(:strategy) { concrete_strategy_class.new(verbose: true) }

      it "logs file write with size" do
        allow(File).to receive(:write)

        expect do
          strategy.send(:write_file, path, content)
        end.to output(/Wrote:.*test\.html/).to_stdout
      end
    end
  end

  describe "#format_size" do
    it "formats bytes" do
      expect(strategy.send(:format_size, 500)).to eq("500 B")
    end

    it "formats kilobytes" do
      expect(strategy.send(:format_size, 2048)).to eq("2.0 KB")
    end

    it "formats megabytes" do
      expect(strategy.send(:format_size, 1_572_864)).to eq("1.5 MB")
    end

    it "rounds to one decimal place" do
      expect(strategy.send(:format_size, 1234)).to eq("1.2 KB")
    end

    it "handles edge case at 1KB boundary" do
      expect(strategy.send(:format_size, 1024)).to eq("1.0 KB")
    end

    it "handles edge case at 1MB boundary" do
      expect(strategy.send(:format_size, 1_048_576)).to eq("1.0 MB")
    end
  end

  describe "#log" do
    context "when verbose mode enabled" do
      subject(:strategy) { concrete_strategy_class.new(verbose: true) }

      it "outputs message" do
        expect do
          strategy.send(:log, "Test message")
        end.to output("Test message\n").to_stdout
      end
    end

    context "when verbose mode disabled" do
      it "does not output message" do
        expect do
          strategy.send(:log, "Test message")
        end.not_to output.to_stdout
      end
    end
  end

  describe "template method pattern" do
    it "defines overall algorithm in base class" do
      # The #write method defines the algorithm
      expect(described_class.instance_methods(false)).to include(:write)
    end

    it "requires subclasses to implement write_files" do
      base_strategy = described_class.new

      expect do
        base_strategy.send(:write_files, "", {})
      end.to raise_error(NotImplementedError)
    end

    it "allows subclasses to override prepare_output" do
      custom_strategy = Class.new(described_class) do
        attr_reader :prepared

        def initialize
          super
          @prepared = false
        end

        protected

        def prepare_output
          @prepared = true
        end

        def write_files(_html, _data)
          []
        end
      end

      instance = custom_strategy.new
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)

      instance.write("", {})
      expect(instance.prepared).to be true
    end
  end

  describe "edge cases" do
    it "handles empty file list" do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:size).and_return(100)

      expect do
        strategy.send(:verify_files, [])
      end.not_to raise_error
    end

    it "handles nil content in write_file" do
      allow(File).to receive(:write)

      expect do
        strategy.send(:write_file, "/tmp/test.html", nil)
      end.not_to raise_error
    end

    it "handles very large file sizes" do
      size = strategy.send(:format_size, 10_737_418_240)
      expect(size).to match(/MB$/)
    end
  end
end
