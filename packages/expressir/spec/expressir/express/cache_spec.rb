require "tempfile"
require "spec_helper"
require_relative "../../../lib/expressir/express/parser"
require_relative "../../../lib/expressir/express/cache"

TEST_VERSION = "0.0.0".freeze

RSpec.describe Expressir::Express::Cache do
  describe ".to_file" do
    it "exports an object" do |_example|
      temp_file = Tempfile.new

      repository = Expressir::Model::Repository.new

      begin
        described_class.to_file(temp_file, repository,
                                test_overwrite_version: TEST_VERSION)

        size = File.size(temp_file)

        expect(size).to be > 0
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe ".from_file" do
    it "throws an exception if the cache file does not exist" do |_example|
      expect do
        described_class.from_file("non-existing-file",
                                  test_overwrite_version: TEST_VERSION)
      end.to raise_error(Errno::ENOENT)
    end

    it "loads a cache file" do |_example|
      temp_file = Tempfile.new

      repository = Expressir::Model::Repository.new

      begin
        described_class.to_file(temp_file, repository,
                                test_overwrite_version: TEST_VERSION)

        result = described_class.from_file(temp_file,
                                           test_overwrite_version: TEST_VERSION)

        expect(result.content).to be_instance_of(Expressir::Model::Repository)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    it "fails parsing a cache from a different Expressir version" do |_example|
      temp_file = Tempfile.new

      repository = Expressir::Model::Repository.new

      begin
        described_class.to_file(temp_file, repository,
                                test_overwrite_version: TEST_VERSION)

        expect do
          described_class.from_file(temp_file)
        end.to raise_error(Expressir::Express::Error::CacheVersionMismatchError)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end

  describe "cache integrity" do
    let(:repository) { Expressir::Model::Repository.new }
    let(:temp_file) { Tempfile.new }

    after do
      temp_file.close
      temp_file.unlink
    end

    it "detects a corrupted cache file" do
      described_class.to_file(temp_file, repository,
                              test_overwrite_version: TEST_VERSION)
      raw = File.binread(temp_file)
      raw.setbyte(raw.bytesize - 5, raw.getbyte(raw.bytesize - 5) ^ 0xFF)
      File.binwrite(temp_file, raw)

      expect do
        described_class.from_file(temp_file,
                                  test_overwrite_version: TEST_VERSION)
      end.to raise_error(Expressir::Express::Error::CacheCorruptedError)
    end

    it "detects a truncated cache file" do
      described_class.to_file(temp_file, repository,
                              test_overwrite_version: TEST_VERSION)
      File.binwrite(temp_file, File.binread(temp_file)[0, 20])

      expect do
        described_class.from_file(temp_file,
                                  test_overwrite_version: TEST_VERSION)
      end.to raise_error(Expressir::Express::Error::CacheCorruptedError)
    end

    it "rejects a file that is not an Expressir cache" do
      File.binwrite(temp_file, "not a cache at all")

      expect do
        described_class.from_file(temp_file,
                                  test_overwrite_version: TEST_VERSION)
      end.to raise_error(Expressir::Express::Error::CacheCorruptedError)
    end

    it "round-trips model content through Marshal" do
      schema = Expressir::Model::Declarations::Schema.new(id: "s")
      repository.files = [Expressir::Model::ExpFile.new(schemas: [schema])]

      described_class.to_file(temp_file, repository,
                              test_overwrite_version: TEST_VERSION)
      result = described_class.from_file(temp_file,
                                         test_overwrite_version: TEST_VERSION)

      expect(result.content.files.first.schemas.first.id).to eq("s")
    end
  end
end
