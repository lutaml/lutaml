# frozen_string_literal: true

require "spec_helper"
require "lutaml/qea/benchmark"

RSpec.describe Lutaml::Qea::Benchmark do
  let(:qea_file_path) { File.join(__dir__, "../../fixtures/test.qea") }
  let(:xmi_file_path) { File.join(__dir__, "../../fixtures/test.xmi") }

  describe ".measure_qea" do
    it "measures QEA parsing performance" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      expect(result).to be_a(Hash)
      expect(result[:file]).to eq(qea_file_path)
      expect(result[:format]).to eq("QEA")
      expect(result[:time]).to be_a(Numeric)
      expect(result[:time]).to be > 0
      expect(result[:file_size_mb]).to be > 0
    end

    it "includes parsing statistics" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      expect(result[:stats]).to be_a(Hash)
      expect(result[:stats]).to have_key(:packages)
      expect(result[:stats]).to have_key(:classes)
      expect(result[:stats]).to have_key(:associations)
      expect(result[:stats]).to have_key(:diagrams)
    end

    it "calculates throughput" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.measure_qea(qea_file_path)

      if result[:file_size_mb] > 0
        expect(result[:throughput_mb_per_sec]).to be_a(Numeric)
        expect(result[:throughput_mb_per_sec]).to be > 0
      end
    end

    it "handles non-existent files gracefully" do
      result = described_class.measure_qea("nonexistent.qea")

      expect(result[:error]).to match(/not found/i)
    end

    it "handles parsing errors gracefully" do
      Tempfile.create(["invalid", ".qea"]) do |f|
        f.write("invalid content")
        f.flush

        result = described_class.measure_qea(f.path)

        expect(result).to have_key(:error)
      end
    end
  end

  describe ".measure_xmi" do
    it "measures XMI parsing performance" do
      skip "XMI test file not available" unless File.exist?(xmi_file_path)

      result = described_class.measure_xmi(xmi_file_path)

      expect(result).to be_a(Hash)
      expect(result[:file]).to eq(xmi_file_path)
      expect(result[:format]).to eq("XMI")
      expect(result[:time]).to be_a(Numeric)
      expect(result[:time]).to be > 0
    end

    it "handles non-existent files gracefully" do
      result = described_class.measure_xmi("nonexistent.xmi")

      expect(result[:error]).to match(/not found/i)
    end
  end

  describe ".compare" do
    it "compares QEA and XMI parsing" do
      skip "Test files not available" unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)

      result = described_class.compare(qea_file_path, xmi_file_path)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:qea)
      expect(result).to have_key(:xmi)
      expect(result).to have_key(:speedup)
      expect(result).to have_key(:improvement_percent)
    end

    it "calculates speedup correctly" do
      skip "Test files not available" unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)

      result = described_class.compare(qea_file_path, xmi_file_path)

      expect(result[:speedup]).to be_a(Numeric)
      expect(result[:speedup]).to be > 0

      # QEA should typically be faster
      expect(result[:speedup]).to be >= 1.0
    end

    it "calculates improvement percentage" do
      skip "Test files not available" unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)

      result = described_class.compare(qea_file_path, xmi_file_path)

      expect(result[:improvement_percent]).to be_a(Numeric)
    end
  end

  describe ".format_results" do
    it "formats comparison results as text" do
      skip "Test files not available" unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)

      results = described_class.compare(qea_file_path, xmi_file_path)
      formatted = described_class.format_results(results)

      expect(formatted).to be_a(String)
      expect(formatted).to include("QEA vs XMI Performance Comparison")
      expect(formatted).to include("QEA File:")
      expect(formatted).to include("XMI File:")
      expect(formatted).to include("Performance Improvement:")
    end

    it "includes speedup information" do
      skip "Test files not available" unless File.exist?(qea_file_path) && File.exist?(xmi_file_path)

      results = described_class.compare(qea_file_path, xmi_file_path)
      formatted = described_class.format_results(results)

      expect(formatted).to match(/faster than XMI/)
      expect(formatted).to match(/Improvement:/)
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