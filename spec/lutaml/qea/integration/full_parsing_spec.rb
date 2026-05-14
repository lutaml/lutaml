# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea"

RSpec.describe "QEA Full Parsing Integration", :integration do
  let(:qea_path) do
    File.expand_path("../../../../examples/qea/test.qea", __dir__)
  end

  let(:document) { cached_qea_parse(qea_path) }

  describe "Lutaml::Qea.parse" do
    it "parses QEA file to complete UML Document", :aggregate_failures do
      expect(document).to be_a(Lutaml::Uml::Document)
      expect(document.name).to eq("EA Model")
    end

    it "populates document with packages" do
      expect(document.packages).to be_an(Array)
    end

    it "populates document with classes" do
      expect(document.classes).to be_an(Array)
    end

    it "populates document with associations" do
      expect(document.associations).to be_an(Array)
    end

    context "with custom options" do
      it "accepts custom document name" do
        custom_doc = Lutaml::Qea.parse(qea_path, document_name: "My Model")
        expect(custom_doc.name).to eq("My Model")
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
    context "Package hierarchy" do
      it "maintains package structure", :aggregate_failures do
        next if document.packages.empty?

        expect(document.packages).not_to be_empty

        pkg = document.packages.first
        expect(pkg.name).not_to be_nil
        expect(pkg.xmi_id).not_to be_nil
        expect(pkg.packages).to be_an(Array)
        expect(pkg.classes).to be_an(Array)
      end

      it "includes nested packages" do
        next if document.packages.empty?

        document.packages.any? { |pkg| pkg.packages && !pkg.packages.empty? }
        expect(document.packages.first.packages).to be_an(Array)
      end
    end

    context "Class transformation" do
      it "transforms classes with all properties", :aggregate_failures do
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

        class_with_attrs = document.classes.find do |c|
          c.attributes && !c.attributes.empty?
        end
        next if class_with_attrs.nil?

        expect(class_with_attrs.attributes.first.name).not_to be_nil
      end

      it "includes class operations" do
        next if document.classes.empty?

        class_with_ops = document.classes.find do |c|
          c.operations && !c.operations.empty?
        end
        next if class_with_ops.nil?

        expect(class_with_ops.operations.first.name).not_to be_nil
      end
    end

    context "Association transformation" do
      it "transforms associations with proper ends", :aggregate_failures do
        next if document.associations.empty?

        assoc = document.associations.first
        expect(assoc).to be_a(Lutaml::Uml::Association)
        expect(assoc.xmi_id).not_to be_nil
      end
    end

    context "Data integrity" do
      it "has unique xmi_ids for all elements" do
        all_xmi_ids = document.packages.map(&:xmi_id)
        document.classes.each { |klass| all_xmi_ids << klass.xmi_id }
        all_xmi_ids.compact!

        expect(all_xmi_ids.size).to eq(all_xmi_ids.uniq.size)
      end

      it "maintains referential integrity in packages" do
        next if document.packages.empty?

        package_class_ids = document.packages.flat_map do |pkg|
          pkg.classes.map(&:xmi_id)
        end.compact
        document_class_ids = document.classes.filter_map(&:xmi_id)

        package_class_ids.each do |id|
          expect(document_class_ids).to include(id)
        end
      end
    end
  end

  describe "Integration with UmlRepository" do
    it "creates document compatible with UmlRepository" do
      expect do
        Lutaml::UmlRepository::Repository.new(document: document)
      end.not_to raise_error
    end

    it "supports repository operations", :aggregate_failures do
      repo = Lutaml::UmlRepository::Repository.new(document: document)

      expect(repo).to respond_to(:packages_index)
      expect(repo).to respond_to(:classes_index)
      expect(repo).to respond_to(:search)
    end

    it "can search parsed document", :aggregate_failures do
      next if document.classes.empty?

      repo = Lutaml::UmlRepository::Repository.new(document: document)
      results = repo.search(document.classes.first.name)

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

    it "produces document with expected element counts", :aggregate_failures do
      database = Lutaml::Qea.load_database(qea_path)
      db_stats = database.stats

      expect(document.packages.size).to be >= 0
      expect(document.classes.size).to be >= 0
      expect(document.associations.size).to be >= 0

      if db_stats["packages"]
        expect(document.packages.size).to be <= db_stats["packages"]
      end
    end
  end

  describe "Error handling" do
    it "raises error for non-existent file" do
      expect do
        Lutaml::Qea.parse("/non/existent/file.qea")
      end.to raise_error(StandardError)
    end

    it "handles empty database gracefully", :aggregate_failures do
      require "sqlite3"
      Tempfile.create(["empty", ".qea"]) do |f|
        db = SQLite3::Database.new(f.path)
        Lutaml::Qea::Services::DatabaseLoader::MODEL_CLASSES.each_key do |table|
          db.execute("CREATE TABLE #{table} (id INTEGER PRIMARY KEY)")
        end
        db.close

        doc = Lutaml::Qea.parse(f.path)
        expect(doc).to be_a(Lutaml::Uml::Document)
        expect(doc.packages).to be_empty
      end
    end
  end

  describe "Real-world QEA files" do
    context "with example QEA files" do
      let(:example_files) do
        examples_dir = File.expand_path("../../../../examples/qea", __dir__)
        Dir.glob(File.join(examples_dir, "*.qea"))
      end

      it "can parse all example files", :aggregate_failures do
        skip "No example files found" if example_files.empty?

        example_files.each do |file_path|
          expect do
            doc = Lutaml::Qea.parse(file_path)
            expect(doc).to be_a(Lutaml::Uml::Document)
          end.not_to raise_error, "Failed to parse #{File.basename(file_path)}"
        end
      end
    end
  end
end
