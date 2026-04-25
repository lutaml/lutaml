# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/" \
                 "static_site/id_generator"

RSpec.describe Lutaml::UmlRepository::StaticSite::IDGenerator do
  let(:generator) { described_class.new }

  # Test entity doubles
  let(:package) { double("Package", xmi_id: "pkg_xmi_123") }
  let(:klass) { double("Class", xmi_id: "cls_xmi_456") }
  let(:attribute) { double("Attribute", name: "testAttr") }
  let(:owner) { double("Owner", xmi_id: "owner_xmi_789") }
  let(:association) { double("Association", xmi_id: "assoc_xmi_012") }
  let(:operation) { double("Operation", name: "testOp") }
  let(:diagram) { double("Diagram", xmi_id: "diag_xmi_345") }

  describe "#initialize" do
    it "initializes with empty cache" do
      expect(generator.instance_variable_get(:@cache)).to be_empty
    end
  end

  describe "#package_id" do
    it "generates stable ID for package", :aggregate_failures do
      id = generator.package_id(package)
      expect(id).to start_with("pkg_")
      expect(id.length).to eq(12) # "pkg_" + 8 char hash
    end

    it "generates same ID for same package across calls" do
      id1 = generator.package_id(package)
      id2 = generator.package_id(package)
      expect(id1).to eq(id2)
    end

    it "uses cache for subsequent calls", :aggregate_failures do
      id1 = generator.package_id(package)

      #  Cache should be populated
      cache = generator.instance_variable_get(:@cache)
      expect(cache).not_to be_empty

      id2 = generator.package_id(package)
      expect(id2).to eq(id1)
    end

    it "generates different IDs for different packages" do
      package2 = double("Package2", xmi_id: "pkg_xmi_999")

      id1 = generator.package_id(package)
      id2 = generator.package_id(package2)

      expect(id1).not_to eq(id2)
    end
  end

  describe "#class_id" do
    it "generates stable ID for class", :aggregate_failures do
      id = generator.class_id(klass)
      expect(id).to start_with("cls_")
      expect(id.length).to eq(12)
    end

    it "generates same ID for same class across calls" do
      id1 = generator.class_id(klass)
      id2 = generator.class_id(klass)
      expect(id1).to eq(id2)
    end

    it "generates different IDs for different classes" do
      klass2 = double("Class2", xmi_id: "cls_xmi_999")

      id1 = generator.class_id(klass)
      id2 = generator.class_id(klass2)

      expect(id1).not_to eq(id2)
    end
  end

  describe "#attribute_id" do
    it "generates stable ID for attribute", :aggregate_failures do
      id = generator.attribute_id(attribute, owner)
      expect(id).to start_with("attr_")
      expect(id.length).to eq(13) # "attr_" + 8 char hash
    end

    it "uses combination of owner and attribute name" do
      # Same attribute name but different owner should give different ID
      owner2 = double("Owner2", xmi_id: "owner_xmi_999")

      id1 = generator.attribute_id(attribute, owner)
      id2 = generator.attribute_id(attribute, owner2)

      expect(id1).not_to eq(id2)
    end

    it "generates same ID for same attribute-owner pair" do
      id1 = generator.attribute_id(attribute, owner)
      id2 = generator.attribute_id(attribute, owner)
      expect(id1).to eq(id2)
    end
  end

  describe "#association_id" do
    it "generates stable ID for association", :aggregate_failures do
      id = generator.association_id(association)
      expect(id).to start_with("assoc_")
      expect(id.length).to eq(14)  # "assoc_" + 8 char hash
    end

    it "generates same ID for same association" do
      id1 = generator.association_id(association)
      id2 = generator.association_id(association)
      expect(id1).to eq(id2)
    end
  end

  describe "#operation_id" do
    it "generates stable ID for operation", :aggregate_failures do
      id = generator.operation_id(operation, owner)
      expect(id).to start_with("op_")
      expect(id.length).to eq(11)  # "op_" + 8 char hash
    end

    it "uses combination of owner and operation name" do
      owner2 = double("Owner2", xmi_id: "owner_xmi_999")

      id1 = generator.operation_id(operation, owner)
      id2 = generator.operation_id(operation, owner2)

      expect(id1).not_to eq(id2)
    end
  end

  describe "#diagram_id" do
    it "generates stable ID for diagram", :aggregate_failures do
      id = generator.diagram_id(diagram)
      expect(id).to start_with("diag_")
      expect(id.length).to eq(13)  # "diag_" + 8 char hash
    end

    it "generates same ID for same diagram" do
      id1 = generator.diagram_id(diagram)
      id2 = generator.diagram_id(diagram)
      expect(id1).to eq(id2)
    end
  end

  describe "#document_id" do
    it "generates stable ID for search document" do
      id = generator.document_id("class", "cls_xmi_456")
      expect(id).to start_with("doc_class_")
    end

    it "includes document type in ID", :aggregate_failures do
      id1 = generator.document_id("class", "xmi_123")
      id2 = generator.document_id("attribute", "xmi_123")

      expect(id1).to include("class")
      expect(id2).to include("attribute")
      expect(id1).not_to eq(id2)
    end

    it "generates same ID for same type and entity" do
      id1 = generator.document_id("class", "xmi_123")
      id2 = generator.document_id("class", "xmi_123")
      expect(id1).to eq(id2)
    end
  end

  describe "#clear_cache" do
    it "clears the internal cache" do
      # Generate some IDs to populate cache
      aggregate_failures do
        generator.package_id(package)
        generator.class_id(klass)

        cache = generator.instance_variable_get(:@cache)
        expect(cache).not_to be_empty

        # Clear cache
        generator.clear_cache

        cache_after = generator.instance_variable_get(:@cache)
        expect(cache_after).to be_empty
      end
    end

    it "allows regeneration of IDs after cache clear" do
      id_before = generator.package_id(package)
      generator.clear_cache
      id_after = generator.package_id(package)

      # Should generate same ID (stable hashing)
      expect(id_after).to eq(id_before)
    end
  end

  describe "ID stability" do
    it "generates consistent IDs across different generator instances" do
      generator1 = described_class.new
      generator2 = described_class.new

      id1 = generator1.package_id(package)
      id2 = generator2.package_id(package)

      expect(id1).to eq(id2)
    end

    it "generates IDs that are collision-resistant" do
      # Generate many IDs and check for collisions
      ids = []

      100.times do |i|
        pkg = double("Package#{i}", xmi_id: "pkg_#{i}")
        ids << generator.package_id(pkg)
      end

      # All IDs should be unique
      expect(ids.uniq.size).to eq(ids.size)
    end
  end

  describe "performance" do
    it "caches IDs for improved performance" do
      # First call
      start_time = Time.now
      1000.times { generator.package_id(package) }
      cached_time = Time.now - start_time

      # Cached calls should be much faster than generation
      expect(cached_time).to be < 0.1 # Should complete in under 100ms
    end
  end

  describe "edge cases" do
    it "handles nil XMI IDs gracefully" do
      package_nil = double("PackageNil", xmi_id: nil)

      expect do
        generator.package_id(package_nil)
      end.not_to raise_error
    end

    it "handles empty XMI IDs", :aggregate_failures do
      package_empty = double("PackageEmpty", xmi_id: "")

      id = generator.package_id(package_empty)
      expect(id).to be_a(String)
      expect(id).to start_with("pkg_")
    end

    it "handles very long XMI IDs" do
      long_id = "x" * 1000
      package_long = double("PackageLong", xmi_id: long_id)

      id = generator.package_id(package_long)
      expect(id.length).to eq(12) # Still short despite long input
    end

    it "handles special characters in XMI IDs" do
      special_id = "pkg-123_abc.xyz@test"
      package_special = double("PackageSpecial", xmi_id: special_id)

      id = generator.package_id(package_special)
      expect(id).to match(/^pkg_[a-f0-9]{8}$/)
    end
  end
end
