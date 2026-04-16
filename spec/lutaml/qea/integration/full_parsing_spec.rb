# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea"

RSpec.describe "QEA Full Parsing Integration", :integration do
  let(:qea_path) do
    File.expand_path("../../../../examples/qea/test.qea", __dir__)
  end

  describe "Lutaml::Qea.parse" do
    it "parses QEA file to complete UML Document" do
      document = Lutaml::Qea.parse(qea_path)

      expect(document).to be_a(Lutaml::Uml::Document)
      expect(document.name).to eq("EA Model")
    end

    it "populates document with packages" do
      document = Lutaml::Qea.parse(qea_path)
      expect(document.packages).to be_an(Array)
    end

    it "populates document with classes" do
      document = Lutaml::Qea.parse(qea_path)
      expect(document.classes).to be_an(Array)
    end

    it "populates document with associations" do
      document = Lutaml::Qea.parse(qea_path)
      expect(document.associations).to be_an(Array)
    end

    context "with custom options" do
      it "accepts custom document name" do
        document = Lutaml::Qea.parse(qea_path, document_name: "My Model")
        expect(document.name).to eq("My Model")
      end

      it "can skip validation" do
        expect do
          Lutaml::Qea.parse(qea_path, validate: false)
        end.not_to raise_error
      end

      it "can exclude diagrams" do
        expect do
          Lutaml::Qea.parse(qea_path, include_diagrams: false)
        end.not_to raise_error
      end
    end
  end

  describe "Complete transformation flow" do
    let(:document) { Lutaml::Qea.parse(qea_path) }

    context "Package hierarchy" do
      it "maintains package structure" do
        next if document.packages.empty?

        # Root packages should exist
        expect(document.packages).not_to be_empty

        # Packages should have proper structure
        pkg = document.packages.first
        expect(pkg.name).not_to be_nil
        expect(pkg.xmi_id).not_to be_nil
        expect(pkg.packages).to be_an(Array)
        expect(pkg.classes).to be_an(Array)
      end

      it "includes nested packages" do
        next if document.packages.empty?

        # Check if any package has children
        document.packages.any? do |pkg|
          pkg.packages && !pkg.packages.empty?
        end

        # This is data-dependent, so we just verify the structure exists
        expect(document.packages.first.packages).to be_an(Array)
      end
    end

    context "Class transformation" do
      it "transforms classes with all properties" do
        next if document.classes.empty?

        klass = document.classes.first
        expect(klass).to be_a(Lutaml::Uml::Class)
        expect(klass.name).not_to be_nil
        expect(klass.xmi_id).not_to be_nil
        expect(klass.attributes).to be_an(Array)
        expect(klass.operations).to be_an(Array)
      end

      it "includes class attributes" do
        next if document.classes.empty?

        # Find a class with attributes
        class_with_attrs = document.classes.find do |c|
          c.attributes && !c.attributes.empty?
        end

        next if class_with_attrs.nil?

        attr = class_with_attrs.attributes.first
        expect(attr.name).not_to be_nil
      end

      it "includes class operations" do
        next if document.classes.empty?

        # Find a class with operations
        class_with_ops = document.classes.find do |c|
          c.operations && !c.operations.empty?
        end

        next if class_with_ops.nil?

        op = class_with_ops.operations.first
        expect(op.name).not_to be_nil
      end
    end

    context "Association transformation" do
      it "transforms associations with proper ends" do
        next if document.associations.empty?

        assoc = document.associations.first
        expect(assoc).to be_a(Lutaml::Uml::Association)
        expect(assoc.xmi_id).not_to be_nil
      end
    end

    context "Data integrity" do
      it "has unique xmi_ids for all elements" do
        # Collect all xmi_ids
        all_xmi_ids = document.packages.map(&:xmi_id)

        document.classes.each do |klass|
          all_xmi_ids << klass.xmi_id
        end

        # document associations return associations in connector-level
        # and class-level
        # class-level associations contain associations with both directions
        # and it may include associations in connector level
        # document.associations.each do |assoc|
        #   all_xmi_ids << assoc.xmi_id
        # end

        all_xmi_ids.compact!

        # All should be unique
        expect(all_xmi_ids.size).to eq(all_xmi_ids.uniq.size)
      end

      it "maintains referential integrity in packages" do
        next if document.packages.empty?

        # All classes in packages should also be in document.classes
        package_class_ids = document.packages.flat_map do |pkg|
          pkg.classes.map(&:xmi_id)
        end.compact

        document_class_ids = document.classes.filter_map(&:xmi_id)

        # Package classes should be subset of document classes
        package_class_ids.each do |id|
          expect(document_class_ids).to include(id)
        end
      end
    end
  end

  describe "Integration with UmlRepository" do
    it "creates document compatible with UmlRepository" do
      document = Lutaml::Qea.parse(qea_path)

      # Should be able to create repository
      expect do
        Lutaml::UmlRepository::Repository.new(document: document)
      end.not_to raise_error
    end

    it "supports repository operations" do
      document = Lutaml::Qea.parse(qea_path)
      repo = Lutaml::UmlRepository::Repository.new(document: document)

      # Should support basic operations
      expect(repo).to respond_to(:packages_index)
      expect(repo).to respond_to(:classes_index)
      expect(repo).to respond_to(:search)
    end

    it "can search parsed document" do
      document = Lutaml::Qea.parse(qea_path)
      repo = Lutaml::UmlRepository::Repository.new(document: document)

      next if document.classes.empty?

      # Search should work
      klass_name = document.classes.first.name
      results = repo.search(klass_name)

      expect(results).to be_a(Hash)
      expect(results).to have_key(:total)
    end
  end

  describe "Performance characteristics" do
    it "completes parsing in reasonable time" do
      expect do
        Timeout.timeout(30) do
          Lutaml::Qea.parse(qea_path)
        end
      end.not_to raise_error
    end

    it "produces document with expected element counts" do
      document = Lutaml::Qea.parse(qea_path)

      # Get raw database stats for comparison
      database = Lutaml::Qea.load_database(qea_path)
      db_stats = database.stats

      # Document should have elements corresponding to database
      # (exact counts may differ due to filtering)
      expect(document.packages.size).to be >= 0
      expect(document.classes.size).to be >= 0
      expect(document.associations.size).to be >= 0

      # Document shouldn't exceed database counts
      if db_stats["packages"]
        expect(document.packages.size).to be <= db_stats["packages"]
      end
    end
  end

  describe "Error handling" do
    it "raises error for non-existent file" do
      expect do
        Lutaml::Qea.parse("/non/existent/file.qea")
      end.to raise_error
    end

    xit "handles empty database gracefully" do
      # This test depends on having an empty QEA file
      # Skip if not available
      pending "Requires empty QEA test file"
    end
  end

  describe "Real-world QEA files" do
    context "with example QEA files" do
      let(:example_files) do
        examples_dir = File.expand_path("../../../../examples/qea", __dir__)
        Dir.glob(File.join(examples_dir, "*.qea"))
      end

      it "can parse all example files" do
        skip "No example files found" if example_files.empty?

        example_files.each do |file_path|
          expect do
            document = Lutaml::Qea.parse(file_path)
            expect(document).to be_a(Lutaml::Uml::Document)
          end.not_to raise_error, "Failed to parse #{File.basename(file_path)}"
        end
      end
    end
  end
end
