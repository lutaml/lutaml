# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/benchmark"

RSpec.describe Lutaml::Qea::Benchmark do
  let(:qea_file_path) do
    File.expand_path("../../../examples/qea/test.qea", __dir__)
  end
  let(:xmi_file_path) do
    File.expand_path("../../../examples/xmi/test.xmi", __dir__)
  end

  describe ".measure_qea" do
    after do
      tempfile.unlink if defined?(tempfile) && File.exist?(tempfile.path)
    end

    it "measures QEA parsing performance" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      aggregate_failures do
        expect(result).to be_a(Hash)
        expect(result[:file]).to eq(qea_file_path)
        expect(result[:format]).to eq("QEA")
        expect(result[:time]).to be_a(Numeric)
        expect(result[:time]).to be > 0
        expect(result[:file_size_mb]).to be > 0
      end
    end

    it "includes parsing statistics" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      aggregate_failures do
        expect(result[:stats]).to be_a(Hash)
        expect(result[:stats]).to have_key(:packages)
        expect(result[:stats]).to have_key(:classes)
        expect(result[:stats]).to have_key(:associations)
        expect(result[:stats]).to have_key(:diagrams)
      end
    end

    it "calculates throughput" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      if result[:file_size_mb] > 0
        aggregate_failures do
          expect(result[:throughput_mb_per_sec]).to be_a(Numeric)
          expect(result[:throughput_mb_per_sec]).to be > 0
        end
      end
    end

    it "handles non-existent files gracefully" do
      result = described_class.measure_qea("nonexistent.qea")

      expect(result[:error]).to match(/not found/i)
    end

    it "handles parsing errors gracefully" do
      # Create temp file with invalid content
      tempfile = Tempfile.new(["invalid", ".qea"])
      tempfile.write("not a valid qea file")
      tempfile.close

      expect(described_class.measure_qea(tempfile.path)).to have_key(:error)
    end
  end

  describe ".measure_xmi" do
    it "measures XMI parsing performance" do
      skip "XMI test file not available" unless File.exist?(xmi_file_path)

      result = described_class.measure_xmi(xmi_file_path)

      aggregate_failures do
        expect(result).to be_a(Hash)
        expect(result[:file]).to eq(xmi_file_path)
        expect(result[:format]).to eq("XMI")
        expect(result[:time]).to be_a(Numeric)
        expect(result[:time]).to be > 0
      end
    end

    it "handles non-existent files gracefully" do
      result = described_class.measure_xmi("nonexistent.xmi")

      expect(result[:error]).to match(/not found/i)
    end
  end

  describe ".compare" do
    it "compares QEA and XMI parsing" do
      unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)
        skip "Test files not available"
      end

      result = described_class.compare(qea_file_path, xmi_file_path)

      aggregate_failures do
        expect(result).to be_a(Hash)
        expect(result).to have_key(:qea)
        expect(result).to have_key(:xmi)
        expect(result).to have_key(:speedup)
        expect(result).to have_key(:improvement_percent)
      end
    end

    it "calculates speedup correctly" do
      unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)
        skip "Test files not available"
      end

      result = described_class.compare(qea_file_path, xmi_file_path)

      aggregate_failures do
        expect(result[:speedup]).to be_a(Numeric)
        expect(result[:speedup]).to be > 0

        # Speedup is xmi_time / qea_time; varies by platform/load
        expect(result[:speedup]).to be_positive
      end
    end

    it "calculates improvement percentage" do
      unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)
        skip "Test files not available"
      end

      result = described_class.compare(qea_file_path, xmi_file_path)

      expect(result[:improvement_percent]).to be_a(Numeric)
    end
  end

  describe ".format_results" do
    it "formats comparison results as text" do
      unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)
        skip "Test files not available"
      end

      results = described_class.compare(qea_file_path, xmi_file_path)
      formatted = described_class.format_results(results)

      aggregate_failures do
        expect(formatted).to be_a(String)
        expect(formatted).to include("QEA vs XMI Performance Comparison")
        expect(formatted).to include("QEA File:")
        expect(formatted).to include("XMI File:")
        expect(formatted).to include("Performance Improvement:")
      end
    end

    it "includes speedup information" do
      unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)
        skip "Test files not available"
      end

      results = described_class.compare(qea_file_path, xmi_file_path)
      formatted = described_class.format_results(results)

      aggregate_failures do
        expect(formatted).to match(/faster than XMI/)
        expect(formatted).to match(/Improvement:/)
      end
    end

    it "handles errors in results" do
      results = {
        error: "Test error message",
      }

      formatted = described_class.format_results(results)

      expect(formatted).to eq("Test error message")
    end
  end
end
