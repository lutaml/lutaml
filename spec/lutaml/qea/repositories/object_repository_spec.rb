# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/repositories/object_repository"
require_relative "../../../../lib/lutaml/qea/models/ea_object"

RSpec.describe Lutaml::Qea::Repositories::ObjectRepository do
  let(:class1) do
    Lutaml::Qea::Models::EaObject.new(
      object_id: 1,
      name: "ClassA",
      object_type: "Class",
      package_id: 10,
      visibility: "Public",
      abstract: "0",
      stereotype: "entity",
    )
  end

  let(:class2) do
    Lutaml::Qea::Models::EaObject.new(
      object_id: 2,
      name: "ClassB",
      object_type: "Class",
      package_id: 10,
      visibility: "Public",
      abstract: "1",
    )
  end

  let(:interface1) do
    Lutaml::Qea::Models::EaObject.new(
      object_id: 3,
      name: "IService",
      object_type: "Interface",
      package_id: 10,
      visibility: "Public",
    )
  end

  let(:enum1) do
    Lutaml::Qea::Models::EaObject.new(
      object_id: 4,
      name: "Status",
      object_type: "Enumeration",
      package_id: 20,
      visibility: "Public",
    )
  end

  let(:component1) do
    Lutaml::Qea::Models::EaObject.new(
      object_id: 5,
      name: "ServiceComponent",
      object_type: "Component",
      package_id: 20,
    )
  end

  let(:records) { [class1, class2, interface1, enum1, component1] }
  let(:repository) { described_class.new(records) }

  describe "#find_by_type" do
    it "finds all classes" do
      results = repository.find_by_type("Class")
      expect(results).to contain_exactly(class1, class2)
    end

    it "finds all interfaces" do
      results = repository.find_by_type("Interface")
      expect(results).to contain_exactly(interface1)
    end

    it "returns empty array for non-existent type" do
      results = repository.find_by_type("NonExistent")
      expect(results).to eq([])
    end
  end

  describe "#find_by_package" do
    it "finds objects in package 10" do
      results = repository.find_by_package(10)
      expect(results).to contain_exactly(class1, class2, interface1)
    end

    it "finds objects in package 20" do
      results = repository.find_by_package(20)
      expect(results).to contain_exactly(enum1, component1)
    end
  end

  describe "#find_by_stereotype" do
    it "finds objects with stereotype" do
      results = repository.find_by_stereotype("entity")
      expect(results).to contain_exactly(class1)
    end

    it "returns empty for non-existent stereotype" do
      results = repository.find_by_stereotype("nonexistent")
      expect(results).to eq([])
    end
  end

  describe "type-specific queries" do
    describe "#classes" do
      it "returns all classes" do
        results = repository.classes
        expect(results).to contain_exactly(class1, class2)
      end
    end

    describe "#interfaces" do
      it "returns all interfaces" do
        results = repository.interfaces
        expect(results).to contain_exactly(interface1)
      end
    end

    describe "#enumerations" do
      it "returns all enumerations" do
        results = repository.enumerations
        expect(results).to contain_exactly(enum1)
      end
    end

    describe "#components" do
      it "returns all components" do
        results = repository.components
        expect(results).to contain_exactly(component1)
      end
    end

    describe "#data_types" do
      it "returns empty when no data types" do
        results = repository.data_types
        expect(results).to eq([])
      end
    end

    describe "#packages" do
      it "returns empty when no package objects" do
        results = repository.packages
        expect(results).to eq([])
      end
    end
  end

  describe "#abstract_objects" do
    it "returns objects with abstract flag" do
      results = repository.abstract_objects
      expect(results).to contain_exactly(class2)
    end
  end

  describe "#find_by_name" do
    it "finds by exact name" do
      results = repository.find_by_name("ClassA")
      expect(results).to contain_exactly(class1)
    end

    it "finds by regex pattern" do
      results = repository.find_by_name(/^Class/)
      expect(results).to contain_exactly(class1, class2)
    end

    it "finds by regex case insensitive" do
      results = repository.find_by_name(/class/i)
      expect(results).to contain_exactly(class1, class2)
    end
  end

  describe "#type_statistics" do
    it "returns count by type" do
      stats = repository.type_statistics
      expect(stats).to eq({
                            "Class" => 2,
                            "Interface" => 1,
                            "Enumeration" => 1,
                            "Component" => 1,
                          })
    end
  end

  describe "#package_statistics" do
    it "returns count by package" do
      stats = repository.package_statistics
      expect(stats).to eq({
                            10 => 3,
                            20 => 2,
                          })
    end
  end

  describe "#object_types" do
    it "returns unique object types" do
      types = repository.object_types
      expect(types).to contain_exactly("Class", "Interface", "Enumeration",
                                       "Component")
    end
  end

  describe "#stereotypes" do
    it "returns unique stereotypes" do
      stereotypes = repository.stereotypes
      expect(stereotypes).to contain_exactly("entity")
    end
  end

  describe "#find_by_visibility" do
    it "finds public objects" do
      results = repository.find_by_visibility("Public")
      expect(results).to contain_exactly(class1, class2, interface1, enum1)
    end
  end

  describe "visibility shortcuts" do
    describe "#public_objects" do
      it "returns all public objects" do
        results = repository.public_objects
        expect(results).to contain_exactly(class1, class2, interface1, enum1)
      end
    end

    describe "#private_objects" do
      it "returns empty when no private objects" do
        results = repository.private_objects
        expect(results).to eq([])
      end
    end

    describe "#protected_objects" do
      it "returns empty when no protected objects" do
        results = repository.protected_objects
        expect(results).to eq([])
      end
    end
  end

  describe "#search" do
    it "searches by name" do
      results = repository.search("Class")
      expect(results).to contain_exactly(class1, class2)
    end

    it "is case insensitive" do
      results = repository.search("class")
      expect(results).to contain_exactly(class1, class2)
    end

    it "searches by alias" do
      obj_with_alias = Lutaml::Qea::Models::EaObject.new(
        object_id: 6,
        name: "Test",
        alias: "SearchMe",
        object_type: "Class",
      )
      repo_with_alias = described_class.new([obj_with_alias])

      results = repo_with_alias.search("search")
      expect(results).to contain_exactly(obj_with_alias)
    end
  end
end
