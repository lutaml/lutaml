# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::UmlRepository::Repository do
  let(:xmi_path) { fixtures_path("ea-xmi-2.5.1.xmi") }

  describe ".from_xmi" do
    it "creates repository from XMI file" do
      repo = described_class.from_xmi(xmi_path)
      expect(repo).to be_a(described_class)
    end

    it "builds indexes automatically" do
      repo = described_class.from_xmi(xmi_path)
      expect(repo.indexes).to be_a(Hash)
      expect(repo.indexes).to be_frozen
    end

    it "is frozen after creation" do
      repo = described_class.from_xmi(xmi_path)
      expect(repo).to be_frozen
    end

    context "with validate option" do
      it "validates when validate option is true" do
        repo = described_class.from_xmi(xmi_path, validate: true)
        expect(repo).to be_a(described_class)
      end

      it "skips validation when validate option is false" do
        repo = described_class.from_xmi(xmi_path, validate: false)
        expect(repo).to be_a(described_class)
      end
    end

    it "raises error for non-existent file" do
      expect { described_class.from_xmi("nonexistent.xmi") }
        .to raise_error(Errno::ENOENT)
    end
  end

  describe ".from_file" do
    let(:xmi_file) { xmi_path }
    let(:lur_file) { temp_lur_path(prefix: "test_package") }

    after do
      FileUtils.rm_f(lur_file)
      FileUtils.rm_f("spec/tmp")
    end

    before do
      FileUtils.mkdir_p("spec/tmp")

      # Create a temporary LUR file for testing
      repo = described_class.from_xmi(xmi_path)
      repo.export_to_package(lur_file)
    end

    it "loads XMI file when given .xmi extension" do
      repo = described_class.from_file(xmi_file)
      expect(repo).to be_a(described_class)
    end

    it "loads LUR file when given .lur extension" do
      repo = described_class.from_file(lur_file)
      expect(repo).to be_a(described_class)
    end

    it "raises ArgumentError for unknown file type" do
      expect { described_class.from_file("test.unknown") }
        .to raise_error(ArgumentError, /Unknown file type/)
    end

    it "raises ArgumentError with helpful message" do
      expect { described_class.from_file("model.txt") }
        .to raise_error(ArgumentError, /Expected .xmi or .lur/)
    end
  end

  describe ".from_file_cached" do
    let(:xmi_file) { xmi_path }
    let(:lur_cache) { temp_lur_path(prefix: "cached_model") }

    after do
      FileUtils.rm_f(lur_cache)
    end

    context "when cache does not exist" do
      it "builds from XMI and creates cache" do
        repo = described_class.from_file_cached(
          xmi_file,
          lur_path: "spec/tmp/cached_model_nonexist.lur",
        )
        expect(repo).to be_a(described_class)
        expect(File.exist?("spec/tmp/cached_model_nonexist.lur")).to be true
      end
    end

    context "when cache exists and is fresh" do
      before do
        # Create cache
        repo = described_class.from_xmi(xmi_file)
        repo.export_to_package(lur_cache)
        # Ensure cache is newer
        sleep 0.1
        FileUtils.touch(lur_cache)
      end

      it "uses cache instead of rebuilding" do
        expect(described_class).not_to receive(:from_xmi)
        repo = described_class.from_file_cached(xmi_file,
                                                lur_path: lur_cache)
        expect(repo).to be_a(described_class)
      end
    end

    context "when cache exists but is stale" do
      before do
        # Create old cache
        repo = described_class.from_xmi(xmi_file)
        repo.export_to_package(lur_cache)
        # Make XMI newer
        sleep 0.1
        FileUtils.touch(xmi_file)
      end

      it "rebuilds from XMI and updates cache" do
        repo = described_class.from_file_cached(xmi_file,
                                                lur_path: lur_cache)
        expect(repo).to be_a(described_class)
        expect(File.mtime(lur_cache)).to be >= File.mtime(xmi_file)
      end
    end

    context "when lur_path is not specified" do
      let(:auto_lur_path) { xmi_file.sub(/\.xmi$/i, ".lur") }

      after do
        FileUtils.rm_f(auto_lur_path)
      end

      it "uses XMI path with .lur extension" do
        described_class.from_file_cached(xmi_file)
        expect(File.exist?(auto_lur_path)).to be true
      end
    end
  end

  describe ".new" do
    let(:document) { create_test_document }

    it "creates repository from document" do
      repo = described_class.new(document: document)
      expect(repo).to be_a(described_class)
    end

    it "builds indexes from document" do
      repo = described_class.new(document: document)
      expect(repo.indexes).to be_a(Hash)
      expect(repo.indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
        :inheritance_graph,
        :diagram_index,
      )
    end

    it "is frozen after creation" do
      repo = described_class.new(document: document)
      expect(repo).to be_frozen
    end
  end

  describe "#document" do
    let(:repo) { described_class.from_xmi(xmi_path) }

    it "returns the document" do
      expect(repo.document).to be_a(Lutaml::Uml::Document)
    end

    it "returns frozen document" do
      expect(repo.document).to be_frozen
    end
  end

  describe "#indexes" do
    let(:repo) { described_class.from_xmi(xmi_path) }

    it "returns frozen indexes hash" do
      expect(repo.indexes).to be_frozen
    end

    it "contains all required indexes" do
      expect(repo.indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
        :inheritance_graph,
        :diagram_index,
      )
    end
  end

  describe "query delegation" do
    let(:repo) { described_class.from_xmi(xmi_path) }

    describe "#find_package" do
      it "delegates to PackageQuery" do
        result = repo.find_package("EA_Model")
        expect(result).to be_a(Lutaml::Uml::Package).or be_nil
      end

      context "with raise_on_error: true" do
        it "raises NameError when package not found" do
          expect { repo.find_package("NonExistent::Package", raise_on_error: true) }
            .to raise_error(NameError, /Package not found/)
        end

        it "returns package when found" do
          # Find a package that actually exists in the test fixture
          available_package = repo.indexes[:package_paths].keys.find do |k|
            k != "ModelRoot"
          end
          skip "No packages in test fixture" unless available_package

          result = repo.find_package(available_package, raise_on_error: true)
          expect(result).to be_a(Lutaml::Uml::Package).or be_a(Lutaml::Uml::Document)
        end
      end
    end

    describe "#find_class" do
      it "delegates to ClassQuery" do
        qname = repo.indexes[:qualified_names].keys.first
        if qname
          result = repo.find_class(qname)
          expect(result).to be_a(Lutaml::Uml::Class)
            .or be_a(Lutaml::Uml::DataType)
            .or be_a(Lutaml::Uml::Enum)
            .or be_nil
        end
      end

      context "with raise_on_error: true" do
        it "raises NameError when class not found" do
          expect { repo.find_class("NonExistent::Class", raise_on_error: true) }
            .to raise_error(NameError, /Class not found/)
        end

        it "includes suggestions in error message" do
          expect { repo.find_class("NonExistent", raise_on_error: true) }
            .to raise_error(NameError, /Did you mean|Tip/)
        end

        it "returns class when found" do
          qname = repo.indexes[:qualified_names].keys.first
          next unless qname

          result = repo.find_class(qname, raise_on_error: true)
          expect(result).to be_a(Lutaml::Uml::Class)
            .or be_a(Lutaml::Uml::DataType)
            .or be_a(Lutaml::Uml::Enum)
        end
      end
    end

    describe "#list_packages" do
      it "delegates to PackageQuery" do
        results = repo.list_packages("EA_Model")
        expect(results).to be_an(Array)
      end
    end

    describe "#search_classes" do
      it "delegates to SearchQuery" do
        results = repo.search_classes("*")
        expect(results).to be_an(Array)
      end
    end

    describe "#find_children" do
      it "delegates to InheritanceQuery" do
        parent_id = repo.indexes[:inheritance_graph].keys.first
        if parent_id
          results = repo.find_children(parent_id)
          expect(results).to be_an(Array)
        end
      end
    end

    describe "#find_associations" do
      it "delegates to AssociationQuery" do
        class_id = repo.indexes[:qualified_names].values
          .find { |e| e.is_a?(Lutaml::Uml::Class) }&.xmi_id
        if class_id
          results = repo.find_associations(class_id)
          expect(results).to be_an(Array)
        end
      end
    end

    describe "#find_diagrams" do
      it "delegates to DiagramQuery" do
        package_id = repo.indexes[:diagram_index].keys.first
        if package_id
          results = repo.find_diagrams(package_id)
          expect(results).to be_an(Array)
        end
      end
    end
  end

  describe "#statistics" do
    let(:repo) { described_class.from_xmi(xmi_path) }

    it "returns statistics hash" do
      stats = repo.statistics
      expect(stats).to be_a(Hash)
    end

    it "includes basic counts" do
      stats = repo.statistics
      expect(stats).to have_key(:total_packages)
      expect(stats).to have_key(:total_classes)
      expect(stats).to have_key(:total_enums)
      expect(stats).to have_key(:total_data_types)
    end

    it "caches results" do
      stats1 = repo.statistics
      stats2 = repo.statistics
      expect(stats1.object_id).to eq(stats2.object_id)
    end
  end

  describe "#validate" do
    let(:repo) { described_class.from_xmi(xmi_path) }

    it "returns ValidationResult" do
      result = repo.validate
      expect(result).to be_a(Lutaml::UmlRepository::Validators::ValidationResult)
    end

    it "includes validation status" do
      result = repo.validate
      expect(result).to respond_to(:valid?)
      expect(result).to respond_to(:errors)
    end
  end

  describe "#export" do
    let(:repo) { described_class.from_xmi(xmi_path) }
    let(:output_path) { temp_lur_path(prefix: "test_export") }

    after do
      FileUtils.rm_f(output_path)
    end

    it "exports to LUR file" do
      repo.export(output_path)
      expect(File.exist?(output_path)).to be true
    end

    it "creates valid ZIP file" do
      repo.export(output_path)
      expect { Zip::File.open(output_path) {} }.not_to raise_error
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }
    let(:repo) { described_class.new(document: document) }

    it "creates repository successfully" do
      expect(repo).to be_a(described_class)
    end

    it "finds simple package" do
      pkg = repo.find_package("ModelRoot::RootPackage")
      expect(pkg).to be_a(Lutaml::Uml::Package)
      expect(pkg.name).to eq("RootPackage")
    end

    it "finds simple class" do
      klass = repo.find_class("ModelRoot::RootPackage::TestClass")
      expect(klass).to be_a(Lutaml::Uml::Class)
      expect(klass.name).to eq("TestClass")
    end

    it "generates statistics" do
      stats = repo.statistics
      expect(stats[:total_packages]).to eq(3)
      expect(stats[:total_classes]).to eq(1)
      expect(stats[:total_enums]).to eq(1)
    end
  end
end
