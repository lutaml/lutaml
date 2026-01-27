# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/qea/database"
require_relative "../../../lib/lutaml/qea/models/ea_object"
require_relative "../../../lib/lutaml/qea/models/ea_package"
require_relative "../../../lib/lutaml/qea/models/ea_attribute"

RSpec.describe Lutaml::Qea::Database do
  let(:qea_path) { "test.qea" }
  let(:database) { described_class.new(qea_path) }

  let(:sample_object) do
    Lutaml::Qea::Models::EaObject.new(
      ea_object_id: 1,
      name: "TestClass",
      object_type: "Class",
      package_id: 10,
    )
  end

  let(:sample_package) do
    Lutaml::Qea::Models::EaPackage.new(
      package_id: 10,
      name: "TestPackage",
      parent_id: 0,
    )
  end

  let(:sample_attribute) do
    Lutaml::Qea::Models::EaAttribute.new(
      id: 100,
      object_id: 1,
      name: "testAttr",
      type: "String",
    )
  end

  describe "#initialize" do
    it "creates a new database instance" do
      expect(database).to be_a(described_class)
    end

    it "stores the QEA path" do
      expect(database.qea_path).to eq(qea_path)
    end

    it "initializes with empty collections" do
      expect(database.collections).to eq({})
    end
  end

  describe "#add_collection" do
    it "adds a collection with symbol key" do
      database.add_collection(:objects, [sample_object])
      expect(database.collections[:objects]).to eq([sample_object])
    end

    it "adds a collection with string key" do
      database.add_collection("objects", [sample_object])
      expect(database.collections[:objects]).to eq([sample_object])
    end

    it "freezes the collection" do
      database.add_collection(:objects, [sample_object])
      expect(database.collections[:objects]).to be_frozen
    end

    it "is thread-safe" do
      threads = 10.times.map do |i|
        Thread.new do
          database.add_collection("collection_#{i}", [sample_object])
        end
      end
      threads.each(&:join)

      expect(database.collections.size).to eq(10)
    end
  end

  describe "#objects" do
    it "returns an ObjectRepository" do
      database.add_collection(:objects, [sample_object])
      expect(database.objects).to be_a(Lutaml::Qea::Repositories::ObjectRepository)
    end

    it "returns empty repository when no objects" do
      repo = database.objects
      expect(repo.all).to eq([])
    end

    it "contains added objects" do
      database.add_collection(:objects, [sample_object])
      expect(database.objects.all).to eq([sample_object])
    end
  end

  describe "#attributes" do
    it "returns attributes collection" do
      database.add_collection(:attributes, [sample_attribute])
      expect(database.attributes).to eq([sample_attribute])
    end

    it "returns empty array when no attributes" do
      expect(database.attributes).to eq([])
    end
  end

  describe "#packages" do
    it "returns packages collection" do
      database.add_collection(:packages, [sample_package])
      expect(database.packages).to eq([sample_package])
    end
  end

  describe "#stats" do
    it "returns empty stats for empty database" do
      expect(database.stats).to eq({})
    end

    it "returns counts for each collection" do
      database.add_collection(:objects, [sample_object, sample_object])
      database.add_collection(:packages, [sample_package])
      database.add_collection(:attributes,
                              [sample_attribute, sample_attribute,
                               sample_attribute])

      stats = database.stats
      expect(stats).to eq({
        "objects" => 2,
        "packages" => 1,
        "attributes" => 3
      })
    end
  end

  describe "#total_records" do
    it "returns 0 for empty database" do
      expect(database.total_records).to eq(0)
    end

    it "returns sum of all records" do
      database.add_collection(:objects, [sample_object, sample_object])
      database.add_collection(:packages, [sample_package])

      expect(database.total_records).to eq(3)
    end
  end

  describe "#find_object" do
    before do
      database.add_collection(:objects, [sample_object])
    end

    it "finds object by ID" do
      result = database.find_object(1)
      expect(result).to eq(sample_object)
    end

    it "returns nil for non-existent ID" do
      result = database.find_object(999)
      expect(result).to be_nil
    end
  end

  describe "#find_package" do
    before do
      database.add_collection(:packages, [sample_package])
    end

    it "finds package by ID" do
      result = database.find_package(10)
      expect(result).to eq(sample_package)
    end

    it "returns nil for non-existent ID" do
      result = database.find_package(999)
      expect(result).to be_nil
    end
  end

  describe "#find_attribute" do
    before do
      database.add_collection(:attributes, [sample_attribute])
    end

    it "finds attribute by ID" do
      result = database.find_attribute(100)
      expect(result).to eq(sample_attribute)
    end

    it "returns nil for non-existent ID" do
      result = database.find_attribute(999)
      expect(result).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true for new database" do
      expect(database.empty?).to be true
    end

    it "returns false when collections exist" do
      database.add_collection(:objects, [sample_object])
      expect(database.empty?).to be false
    end

    it "returns true when collections are empty" do
      database.add_collection(:objects, [])
      expect(database.empty?).to be true
    end
  end

  describe "#collection_names" do
    it "returns empty array for new database" do
      expect(database.collection_names).to eq([])
    end

    it "returns all collection names" do
      database.add_collection(:objects, [sample_object])
      database.add_collection(:packages, [sample_package])

      expect(database.collection_names).to contain_exactly(:objects, :packages)
    end
  end

  describe "#freeze" do
    it "freezes the database" do
      database.freeze
      expect(database).to be_frozen
    end

    it "freezes collections hash" do
      database.add_collection(:objects, [sample_object])
      database.freeze
      expect(database.collections).to be_frozen
    end

    it "prevents adding new collections after freeze" do
      database.freeze
      expect {
        database.add_collection(:new, [sample_object])
      }.to raise_error(FrozenError)
    end
  end
end
