# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/factory/document_builder"

RSpec.describe Lutaml::Qea::Factory::DocumentBuilder do
  let(:builder) { described_class.new(name: "Test Model") }

  # Mock UML elements
  let(:mock_package) do
    double("Package", xmi_id: "PKG-001", name: "TestPackage",
                      classes: [], enums: [], data_types: [], packages: [], instances: [])
  end

  let(:mock_class) do
    double("Class", xmi_id: "CLASS-001", name: "Building")
  end

  let(:mock_enum) do
    double("Enum", xmi_id: "ENUM-001", name: "Status")
  end

  let(:mock_association) do
    double("Association", xmi_id: "ASSOC-001",
                          member_end: "Building",
                          member_end_xmi_id: "CLASS-001",
                          owner_end: "Site",
                          owner_end_xmi_id: "CLASS-002")
  end

  describe "#initialize" do
    it "creates new document builder with default name" do
      builder = described_class.new
      expect(builder.document).to be_a(Lutaml::Uml::Document)
      expect(builder.document.name).to eq("EA Model")
    end

    it "creates new document builder with custom name" do
      expect(builder.document.name).to eq("Test Model")
    end

    it "initializes empty collections" do
      expect(builder.document.packages).to eq([])
      expect(builder.document.classes).to eq([])
      expect(builder.document.enums).to eq([])
      expect(builder.document.data_types).to eq([])
      expect(builder.document.associations).to eq([])
    end
  end

  describe "#add_packages" do
    it "adds packages to document" do
      builder.add_packages([mock_package])
      expect(builder.document.packages).to eq([mock_package])
    end

    it "returns self for method chaining" do
      result = builder.add_packages([mock_package])
      expect(result).to eq(builder)
    end

    it "handles nil gracefully" do
      builder.add_packages(nil)
      expect(builder.document.packages).to eq([])
    end

    it "handles empty array gracefully" do
      builder.add_packages([])
      expect(builder.document.packages).to eq([])
    end

    it "can be called multiple times" do
      pkg1 = double("Package1", xmi_id: "PKG-001")
      pkg2 = double("Package2", xmi_id: "PKG-002")

      builder.add_packages([pkg1])
      builder.add_packages([pkg2])

      expect(builder.document.packages).to eq([pkg1, pkg2])
    end
  end

  describe "#add_classes" do
    it "adds classes to document" do
      builder.add_classes([mock_class])
      expect(builder.document.classes).to eq([mock_class])
    end

    it "returns self for method chaining" do
      result = builder.add_classes([mock_class])
      expect(result).to eq(builder)
    end

    it "handles nil gracefully" do
      builder.add_classes(nil)
      expect(builder.document.classes).to eq([])
    end

    it "handles empty array gracefully" do
      builder.add_classes([])
      expect(builder.document.classes).to eq([])
    end
  end

  describe "#add_enums" do
    it "adds enums to document" do
      builder.add_enums([mock_enum])
      expect(builder.document.enums).to eq([mock_enum])
    end

    it "returns self for method chaining" do
      result = builder.add_enums([mock_enum])
      expect(result).to eq(builder)
    end
  end

  describe "#add_associations" do
    it "adds associations to document" do
      builder.add_associations([mock_association])
      expect(builder.document.associations).to eq([mock_association])
    end

    it "returns self for method chaining" do
      result = builder.add_associations([mock_association])
      expect(result).to eq(builder)
    end
  end

  describe "#set_metadata" do
    it "sets document title" do
      builder.set_metadata(title: "My Model")
      expect(builder.document.title).to eq("My Model")
    end

    it "sets document caption" do
      builder.set_metadata(caption: "Test Caption")
      expect(builder.document.caption).to eq("Test Caption")
    end

    it "sets both title and caption" do
      builder.set_metadata(title: "Title", caption: "Caption")
      expect(builder.document.title).to eq("Title")
      expect(builder.document.caption).to eq("Caption")
    end

    it "returns self for method chaining" do
      result = builder.set_metadata(title: "Test")
      expect(result).to eq(builder)
    end
  end

  describe "#stats" do
    it "returns document statistics" do
      stats = builder.stats
      expect(stats).to have_key(:packages)
      expect(stats).to have_key(:classes)
      expect(stats).to have_key(:enums)
      expect(stats).to have_key(:data_types)
      expect(stats).to have_key(:associations)
    end

    it "reflects current state" do
      builder.add_packages([mock_package])
      builder.add_classes([mock_class])
      builder.add_enums([mock_enum])

      stats = builder.stats
      expect(stats[:packages]).to eq(1)
      expect(stats[:classes]).to eq(1)
      expect(stats[:enums]).to eq(1)
      expect(stats[:associations]).to eq(0)
    end
  end

  describe "#build" do
    context "without validation" do
      it "returns the document" do
        doc = builder.build(validate: false)
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.name).to eq("Test Model")
      end
    end

    context "with validation" do
      it "validates and returns document when valid" do
        builder.add_packages([mock_package])
        builder.add_classes([mock_class])

        doc = builder.build(validate: true)
        expect(doc).to be_a(Lutaml::Uml::Document)
      end

      it "raises error for duplicate xmi_ids" do
        class1 = double("Class1", xmi_id: "SAME-ID")
        class2 = double("Class2", xmi_id: "SAME-ID")

        builder.add_classes([class1, class2])

        expect { builder.build(validate: true) }
          .to raise_error(described_class::ValidationError, /Duplicate xmi_ids/)
      end
    end
  end

  describe "#validate!" do
    context "with valid document" do
      it "returns true" do
        builder.add_packages([mock_package])
        builder.add_classes([mock_class])
        expect(builder.validate!).to be true
      end
    end

    context "with duplicate xmi_ids" do
      it "raises validation error" do
        pkg1 = double(
          "Pkg1", xmi_id: "SAME-ID",
                  classes: [], enums: [], data_types: [], packages: [], instances: []
        )
        pkg2 = double(
          "Pkg2", xmi_id: "SAME-ID",
                  classes: [], enums: [], data_types: [], packages: [], instances: []
        )

        builder.add_packages([pkg1, pkg2])

        expect { builder.validate! }
          .to raise_error(described_class::ValidationError)
      end
    end

    context "with classes in packages" do
      it "collects xmi_ids from nested packages" do
        # Create nested package structure
        inner_class = double("InnerClass", xmi_id: "INNER-CLASS-001",
                                           name: "InnerClass")
        inner_package = double("InnerPackage", xmi_id: "INNER-PKG-001",
                                               classes: [inner_class], enums: [],
                                               data_types: [], packages: [], instances: [])
        outer_package = double("OuterPackage", xmi_id: "OUTER-PKG-001",
                                               classes: [], enums: [], data_types: [],
                                               packages: [inner_package], instances: [])

        # Create association referencing class in nested package
        assoc = double("Assoc",
                       xmi_id: "ASSOC-001",
                       member_end: "InnerClass",
                       member_end_xmi_id: "INNER-CLASS-001",
                       owner_end: "OuterClass",
                       owner_end_xmi_id: "OUTER-CLASS-001")

        outer_class = double("OuterClass", xmi_id: "OUTER-CLASS-001")

        builder.add_packages([outer_package])
        builder.add_classes([outer_class])
        builder.add_associations([assoc])

        # Should not raise error - inner class should be found
        expect { builder.validate! }.not_to raise_error
      end

      it "finds classes deeply nested in package hierarchy" do
        # Create 3-level nesting
        deep_class = double("DeepClass", xmi_id: "DEEP-CLASS-001")
        level3_pkg = double("Level3", xmi_id: "PKG-L3",
                                      classes: [deep_class], enums: [],
                                      data_types: [], packages: [], instances: [])
        level2_pkg = double("Level2", xmi_id: "PKG-L2",
                                      classes: [], enums: [], data_types: [],
                                      packages: [level3_pkg], instances: [])
        level1_pkg = double("Level1", xmi_id: "PKG-L1",
                                      classes: [], enums: [], data_types: [],
                                      packages: [level2_pkg], instances: [])

        assoc = double("Assoc",
                       xmi_id: "ASSOC-DEEP",
                       member_end: "DeepClass",
                       member_end_xmi_id: "DEEP-CLASS-001",
                       owner_end: "TopClass",
                       owner_end_xmi_id: "TOP-CLASS-001")

        top_class = double("TopClass", xmi_id: "TOP-CLASS-001")

        builder.add_packages([level1_pkg])
        builder.add_classes([top_class])
        builder.add_associations([assoc])

        # Should not raise error - deeply nested class should be found
        expect { builder.validate! }.not_to raise_error
      end
    end

    context "with invalid association references" do
      it "removes associations with invalid member_end_xmi_id" do
        assoc = double("Assoc",
                       xmi_id: "ASSOC-001",
                       member_end: "InvalidClass",
                       member_end_xmi_id: "INVALID-ID",
                       owner_end: "ValidClass",
                       owner_end_xmi_id: nil)

        builder.add_associations([assoc])

        # Should warn but not raise error (warnings only)
        expect { builder.validate! }.to output(/invalid member_end/).to_stderr

        # Association should be removed
        expect(builder.document.associations).to be_empty
      end

      it "removes associations with invalid owner_end_xmi_id" do
        class1 = double("Class", xmi_id: "CLASS-001")
        assoc = double("Assoc",
                       xmi_id: "ASSOC-001",
                       member_end: "ValidClass",
                       member_end_xmi_id: "CLASS-001",
                       owner_end: "InvalidClass",
                       owner_end_xmi_id: "INVALID-TYPE")

        builder.add_classes([class1])
        builder.add_associations([assoc])

        # Should warn but not raise error (warnings only)
        expect { builder.validate! }.to output(/invalid owner_end/).to_stderr

        # Association should be removed
        expect(builder.document.associations).to be_empty
      end
    end
  end

  describe "method chaining" do
    it "supports fluent interface" do
      doc = builder
        .add_packages([mock_package])
        .add_classes([mock_class])
        .add_enums([mock_enum])
        .set_metadata(title: "Test", caption: "Caption")
        .build(validate: false)

      expect(doc.packages.size).to eq(1)
      expect(doc.classes.size).to eq(1)
      expect(doc.enums.size).to eq(1)
      expect(doc.title).to eq("Test")
      expect(doc.caption).to eq("Caption")
    end
  end
end
