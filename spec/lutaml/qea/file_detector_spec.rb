# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/file_detector"
require "tempfile"

RSpec.describe Lutaml::Qea::FileDetector do
  let(:qea_file_path) do
    File.expand_path("../../../examples/qea/test.qea", __dir__)
  end

  describe ".qea_file?" do
    it "returns true for valid QEA file" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      expect(described_class.qea_file?(qea_file_path)).to be true
    end

    it "returns false for non-existent file" do
      expect(described_class.qea_file?("nonexistent.qea")).to be false
    end

    it "returns false for file without .qea extension" do
      Tempfile.create(["test", ".txt"]) do |f|
        expect(described_class.qea_file?(f.path)).to be false
      end
    end

    it "returns false for directory" do
      expect(described_class.qea_file?(__dir__)).to be false
    end

    it "returns false for non-SQLite file with .qea extension" do
      Tempfile.create(["invalid", ".qea"]) do |f|
        f.write("not a SQLite file")
        f.flush

        expect(described_class.qea_file?(f.path)).to be false
      end
    end
  end

  describe ".validate_qea" do
    it "validates a proper QEA file", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.validate_qea(qea_file_path)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:valid)
      expect(result).to have_key(:errors)
      expect(result).to have_key(:warnings)
    end

    it "returns errors for non-existent file", :aggregate_failures do
      result = described_class.validate_qea("nonexistent.qea")

      expect(result[:valid]).to be false
      expect(result[:errors]).to include(a_string_matching(/not found/i))
    end

    it "returns errors for non-SQLite file", :aggregate_failures do
      Tempfile.create(["invalid", ".qea"]) do |f|
        f.write("not a SQLite file")
        f.flush

        result = described_class.validate_qea(f.path)

        expect(result[:valid]).to be false
        expect(result[:errors])
          .to include(a_string_matching(/not a valid SQLite/i))
      end
    end

    it "warns about missing .qea extension" do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      # Copy to file without .qea extension
      Tempfile.create(["test", ".db"]) do |f|
        FileUtils.cp(qea_file_path, f.path)

        result = described_class.validate_qea(f.path)

        expect(result[:warnings])
          .to include(a_string_matching(/does not have \.qea extension/i))
      end
    end

    it "checks for required EA tables", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      result = described_class.validate_qea(qea_file_path)

      if result[:valid]
        expect(result[:errors]).to be_empty
      else
        # Should have specific errors about missing tables
        expect(result[:errors]).to all(match(/Missing required EA table/i))
      end
    end
  end

  describe ".file_info" do
    it "returns file information for valid QEA file", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      info = described_class.file_info(qea_file_path)

      expect(info).to be_a(Hash)
      expect(info[:path]).to eq(qea_file_path)
      expect(info[:size_bytes]).to be > 0
      expect(info[:size_mb]).to be > 0
      expect(info[:modified]).to be_a(Time)
      expect(info[:is_qea]).to be true
      expect(info[:is_sqlite]).to be true
    end

    it "returns error for non-existent file", :aggregate_failures do
      info = described_class.file_info("nonexistent.qea")

      expect(info).to have_key(:error)
      expect(info[:error]).to match(/not found/i)
    end

    it "includes table count for SQLite files", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      info = described_class.file_info(qea_file_path)

      expect(info).to have_key(:table_count)
      expect(info[:table_count]).to be > 0
    end

    it "includes EA table validation", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      info = described_class.file_info(qea_file_path)

      expect(info).to have_key(:has_ea_tables)
      expect(info[:has_ea_tables]).to(satisfy { |v| [true, false].include?(v) })
    end

    it "includes record counts for key tables", :aggregate_failures do
      skip "QEA test file not available" unless File.exist?(qea_file_path)

      info = described_class.file_info(qea_file_path)

      if info[:has_ea_tables]
        expect(info).to have_key(:object_count)
        expect(info).to have_key(:package_count)
      end
    end
  end
end
