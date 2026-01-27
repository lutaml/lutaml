# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/repositories/base_repository"
require_relative "../../../../lib/lutaml/qea/models/ea_object"

RSpec.describe Lutaml::Qea::Repositories::BaseRepository do
  let(:object1) do
    Lutaml::Qea::Models::EaObject.new(
      ea_object_id: 1,
      name: "ClassA",
      object_type: "Class",
      visibility: "Public",
    )
  end

  let(:object2) do
    Lutaml::Qea::Models::EaObject.new(
      ea_object_id: 2,
      name: "ClassB",
      object_type: "Interface",
      visibility: "Public",
    )
  end

  let(:object3) do
    Lutaml::Qea::Models::EaObject.new(
      ea_object_id: 3,
      name: "ClassC",
      object_type: "Class",
      visibility: "Private",
    )
  end

  let(:records) { [object1, object2, object3] }
  let(:repository) { described_class.new(records) }

  describe "#initialize" do
    it "creates repository with records" do
      expect(repository.records).to eq(records)
    end

    it "freezes the records array" do
      expect(repository.records).to be_frozen
    end
  end

  describe "#all" do
    it "returns all records" do
      expect(repository.all).to eq(records)
    end
  end

  describe "#find" do
    it "finds record by primary key" do
      result = repository.find(1)
      expect(result).to eq(object1)
    end

    it "returns nil for non-existent ID" do
      result = repository.find(999)
      expect(result).to be_nil
    end
  end

  describe "#where" do
    context "with hash conditions" do
      it "filters by single attribute" do
        results = repository.where(object_type: "Class")
        expect(results).to contain_exactly(object1, object3)
      end

      it "filters by multiple attributes" do
        results = repository.where(object_type: "Class", visibility: "Public")
        expect(results).to contain_exactly(object1)
      end

      it "returns empty array when no matches" do
        results = repository.where(object_type: "NonExistent")
        expect(results).to eq([])
      end
    end

    context "with block" do
      it "filters using block" do
        results = repository.where { |r| r.name.start_with?("Class") }
        expect(results).to eq(records)
      end

      it "filters with complex condition" do
        results = repository.where do |r|
          r.object_type == "Class" && r.visibility == "Public"
        end
        expect(results).to contain_exactly(object1)
      end
    end

    context "without conditions" do
      it "returns all records" do
        results = repository.where
        expect(results).to eq(records)
      end
    end
  end

  describe "#count" do
    it "counts all records" do
      expect(repository.count).to eq(3)
    end

    it "counts with hash conditions" do
      count = repository.count(object_type: "Class")
      expect(count).to eq(2)
    end

    it "counts with block" do
      count = repository.count { |r| r.visibility == "Public" }
      expect(count).to eq(2)
    end
  end

  describe "#find_first" do
    it "finds first matching record with hash" do
      result = repository.find_first(object_type: "Class")
      expect(result).to eq(object1)
    end

    it "finds first matching record with block" do
      result = repository.find_first { |r| r.name.include?("B") }
      expect(result).to eq(object2)
    end

    it "returns nil when no match" do
      result = repository.find_first(object_type: "NonExistent")
      expect(result).to be_nil
    end
  end

  describe "#any?" do
    it "returns true when records match" do
      expect(repository.any?(object_type: "Class")).to be true
    end

    it "returns false when no records match" do
      expect(repository.any?(object_type: "NonExistent")).to be false
    end

    it "works with block" do
      expect(repository.any? { |r| r.name == "ClassA" }).to be true
    end
  end

  describe "#none?" do
    it "returns false when records match" do
      expect(repository.none?(object_type: "Class")).to be false
    end

    it "returns true when no records match" do
      expect(repository.none?(object_type: "NonExistent")).to be true
    end

    it "works with block" do
      expect(repository.none? { |r| r.name == "NonExistent" }).to be true
    end
  end

  describe "#pluck" do
    it "extracts single attribute" do
      result = repository.pluck(:name)
      expect(result).to eq([
        { name: "ClassA" },
        { name: "ClassB" },
        { name: "ClassC" }
      ])
    end

    it "extracts multiple attributes" do
      result = repository.pluck(:ea_object_id, :name)
      expect(result).to eq([
        { ea_object_id: 1, name: "ClassA" },
        { ea_object_id: 2, name: "ClassB" },
        { ea_object_id: 3, name: "ClassC" }
      ])
    end
  end

  describe "#group_by" do
    it "groups records by attribute" do
      result = repository.group_by(:object_type)
      expect(result.keys).to contain_exactly("Class", "Interface")
      expect(result["Class"]).to contain_exactly(object1, object3)
      expect(result["Interface"]).to contain_exactly(object2)
    end
  end

  describe "#order_by" do
    it "sorts ascending by default" do
      result = repository.order_by(:name)
      expect(result.map(&:name)).to eq(["ClassA", "ClassB", "ClassC"])
    end

    it "sorts descending when specified" do
      result = repository.order_by(:name, :desc)
      expect(result.map(&:name)).to eq(["ClassC", "ClassB", "ClassA"])
    end
  end

  describe "#distinct" do
    it "returns unique values" do
      result = repository.distinct(:object_type)
      expect(result).to contain_exactly("Class", "Interface")
    end

    it "filters out nil values" do
      result = repository.distinct(:visibility)
      expect(result).to contain_exactly("Public", "Private")
    end
  end

  describe "#empty?" do
    it "returns false for non-empty repository" do
      expect(repository.empty?).to be false
    end

    it "returns true for empty repository" do
      empty_repo = described_class.new([])
      expect(empty_repo.empty?).to be true
    end
  end

  describe "#size" do
    it "returns record count" do
      expect(repository.size).to eq(3)
    end

    it "returns 0 for empty repository" do
      empty_repo = described_class.new([])
      expect(empty_repo.size).to eq(0)
    end
  end

  describe "#length" do
    it "is an alias for size" do
      expect(repository.length).to eq(repository.size)
    end
  end
end
