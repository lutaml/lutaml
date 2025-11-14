# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/repository"

RSpec.describe Lutaml::UmlRepository::QueryDSL::QueryBuilder do
  let(:xmi_path) do
    File.expand_path("../../../fixtures/sample_model.xmi", __dir__)
  end
  let(:repository) do
    # Create a simple in-memory repository for testing
    document = Lutaml::Uml::Document.new.tap do |doc|
      doc.name = "Test Model"
      doc.packages = create_test_packages
    end
    Lutaml::UmlRepository::UmlRepository.new(document: document)
  end

  def create_test_packages
    [
      Lutaml::Uml::Package.new.tap do |pkg|
        pkg.name = "ModelRoot"
        pkg.packages = [
          Lutaml::Uml::Package.new.tap do |sub|
            sub.name = "TestPackage"
            sub.classes = create_test_classes
          end,
        ]
      end,
    ]
  end

  def create_test_classes
    [
      Lutaml::Uml::Class.new.tap do |klass|
        klass.name = "Building"
        klass.stereotype = ["featureType"]
        klass.attributes = [
          Lutaml::Uml::TopElementAttribute.new(name: "address"),
          Lutaml::Uml::TopElementAttribute.new(name: "height"),
        ]
      end,
      Lutaml::Uml::Class.new.tap do |klass|
        klass.name = "Person"
        klass.stereotype = ["dataType"]
        klass.attributes = [
          Lutaml::Uml::TopElementAttribute.new(name: "name"),
        ]
      end,
      Lutaml::Uml::Class.new.tap do |klass|
        klass.name = "Vehicle"
        klass.stereotype = ["featureType"]
        klass.attributes = Array.new(15) do |i|
          Lutaml::Uml::TopElementAttribute.new(name: "attr_#{i}")
        end
      end,
    ]
  end

  describe "#classes" do
    it "sets scope to classes" do
      builder = repository.query(&:classes)
      expect(builder.execute).to all(be_a(Lutaml::Uml::Class))
    end
  end

  describe "#where with hash conditions" do
    it "filters by exact match" do
      results = repository.query do |q|
        q.classes.where(stereotype: "featureType")
      end.all

      expect(results.map(&:name)).to include("Building", "Vehicle")
      expect(results.map(&:name)).not_to include("Person")
    end

    it "filters by multiple conditions" do
      results = repository.query do |q|
        q.classes.where(stereotype: "featureType", name: "Building")
      end.all

      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Building")
    end

    it "filters by regex pattern" do
      results = repository.query do |q|
        q.classes.where(name: /^B/)
      end.all

      expect(results.map(&:name)).to eq(["Building"])
    end
  end

  describe "#where with block conditions" do
    it "filters using custom logic" do
      results = repository.query do |q|
        q.classes.where { |c| c.attributes&.size.to_i > 10 }
      end.all

      expect(results.map(&:name)).to eq(["Vehicle"])
    end

    it "combines hash and block conditions" do
      results = repository.query do |q|
        q.classes
          .where(stereotype: "featureType")
          .where { |c| c.attributes&.size.to_i > 2 }
      end.all

      expect(results.map(&:name)).to eq(["Vehicle"])
    end
  end

  describe "#with_stereotype" do
    it "filters by stereotype" do
      results = repository.query do |q|
        q.classes.with_stereotype("dataType")
      end.all

      expect(results.map(&:name)).to eq(["Person"])
    end
  end

  describe "#order_by" do
    it "orders by name ascending" do
      results = repository.query do |q|
        q.classes.order_by(:name)
      end.all

      expect(results.map(&:name)).to eq(["Building", "Person", "Vehicle"])
    end

    it "orders by name descending" do
      results = repository.query do |q|
        q.classes.order_by(:name, direction: :desc)
      end.all

      expect(results.map(&:name)).to eq(["Vehicle", "Person", "Building"])
    end
  end

  describe "#limit" do
    it "limits results" do
      results = repository.query do |q|
        q.classes.order_by(:name).limit(2)
      end.all

      expect(results.size).to eq(2)
      expect(results.map(&:name)).to eq(["Building", "Person"])
    end
  end

  describe "#first" do
    it "returns first result" do
      result = repository.query do |q|
        q.classes.order_by(:name)
      end.first

      expect(result.name).to eq("Building")
    end

    it "returns nil when no results" do
      result = repository.query do |q|
        q.classes.where(name: "NonExistent")
      end.first

      expect(result).to be_nil
    end
  end

  describe "#last" do
    it "returns last result" do
      result = repository.query do |q|
        q.classes.order_by(:name)
      end.last

      expect(result.name).to eq("Vehicle")
    end
  end

  describe "#count" do
    it "returns count of results" do
      count = repository.query do |q|
        q.classes.where(stereotype: "featureType")
      end.count

      expect(count).to eq(2)
    end
  end

  describe "#any?" do
    it "returns true when results exist" do
      result = repository.query do |q|
        q.classes.where(stereotype: "featureType")
      end.any?

      expect(result).to be true
    end

    it "returns false when no results" do
      result = repository.query do |q|
        q.classes.where(stereotype: "nonexistent")
      end.any?

      expect(result).to be false
    end
  end

  describe "#empty?" do
    it "returns false when results exist" do
      result = repository.query do |q|
        q.classes.where(stereotype: "featureType")
      end.empty?

      expect(result).to be false
    end

    it "returns true when no results" do
      result = repository.query do |q|
        q.classes.where(stereotype: "nonexistent")
      end.empty?

      expect(result).to be true
    end
  end

  describe "method chaining" do
    it "chains multiple operations" do
      results = repository.query do |q|
        q.classes
          .where(stereotype: "featureType")
          .where { |c| c.attributes&.size.to_i > 1 }
          .order_by(:name, direction: :desc)
          .limit(5)
      end.execute

      expect(results.map(&:name)).to eq(["Vehicle", "Building"])
    end
  end

  describe "repository integration" do
    it "uses query! for immediate execution" do
      results = repository.query! do |q|
        q.classes.where(stereotype: "featureType")
      end

      expect(results.map(&:name)).to include("Building", "Vehicle")
    end

    it "uses query for deferred execution" do
      builder = repository.query do |q|
        q.classes.where(stereotype: "featureType")
      end

      expect(builder).to be_a(Lutaml::UmlRepository::QueryDSL::QueryBuilder)

      results = builder.execute
      expect(results.map(&:name)).to include("Building", "Vehicle")
    end
  end

  describe "error handling" do
    it "raises error when no scope specified" do
      expect do
        repository.query { |q| q }.execute
      end.to raise_error(RuntimeError, /No scope specified/)
    end
  end
end
