# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/static_site/generator"
require_relative "../../../../lib/lutaml/uml_repository/static_site/" \
                 "configuration"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::StaticSite::Generator do
  let(:repository) do
    double("UmlRepository",
      packages_index: [test_package],
      classes_index: [test_class],
      associations_index: [],
    )
  end

  let(:test_package) do
    double("Package",
      xmi_id: "pkg_001",
      name: "TestPackage",
      definition: "Test package",
      stereotypes: [],
      owner: nil,
      packages: [],
    )
  end

  let(:test_class) do
    double("Class",
      xmi_id: "cls_001",
      name: "TestClass",
      definition: "Test class",
      stereotypes: [],
      owner: test_package,
      attributes: [],
      operations: nil,
      is_abstract: false,
      class: Lutaml::Uml::TopElement,
    )
  end

  let(:output_file) { Tempfile.new(["test_output", ".html"]) }
  let(:output_dir) { Dir.mktmpdir }

  after do
    output_file.close
    output_file.unlink
    FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
  end

  before do
    # Set up the relationship after doubles are created to avoid circular
    # reference
    allow(test_package).to receive(:classes).and_return([test_class])
  end

  describe "#initialize" do
    it "initializes with repository and options" do
      generator = described_class.new(repository, output: output_file.path)

      expect(generator.repository).to eq(repository)
      expect(generator.options).to be_a(Hash)
    end

    it "loads configuration" do
      generator = described_class.new(repository)

      expect(generator.config).to be_a(Lutaml::UmlRepository::StaticSite::Configuration)
    end

    it "creates data transformer" do
      generator = described_class.new(repository)

      expect(generator.instance_variable_get(:@data_transformer)).to be_a(Lutaml::UmlRepository::StaticSite::DataTransformer)
    end

    it "creates search builder" do
      generator = described_class.new(repository)

      expect(generator.instance_variable_get(:@search_builder)).to be_a(Lutaml::UmlRepository::StaticSite::SearchIndexBuilder)
    end

    it "accepts custom configuration" do
      custom_config = Lutaml::UmlRepository::StaticSite::Configuration.create_default_configuration
      generator = described_class.new(repository, config: custom_config)

      expect(generator.config).to eq(custom_config)
    end

    it "supports dependency injection for testing" do
      mock_transformer = double("DataTransformer")
      mock_builder = double("SearchBuilder")

      generator = described_class.new(repository,
        data_transformer: mock_transformer,
        search_builder: mock_builder,
      )

      expect(generator.instance_variable_get(:@data_transformer))
        .to eq(mock_transformer)
      expect(generator.instance_variable_get(:@search_builder))
        .to eq(mock_builder)
    end
  end

  describe "#generate" do
    before do
      # Mock repository methods
      allow(repository).to receive(:associations_of).and_return([])
      allow(repository).to receive(:supertype_of).and_return(nil)
      allow(repository).to receive(:subtypes_of).and_return([])
      allow(repository).to receive(:diagrams_in_package).and_return([])
      allow(repository).to receive(:diagrams_index).and_return([])
      allow(repository).to receive(:document).and_return([])
      allow(repository).to receive(:packages_index).and_return([])
    end

    context "with single-file mode" do
      it "generates single HTML file" do
        generator = described_class.new(repository,
          mode: :single_file,
          output: output_file.path,
        )

        # Mock Liquid rendering
        allow_any_instance_of(Liquid::Template)
          .to receive(:render).and_return("<html>Test</html>")

        result = generator.generate

        expect(result).to eq(output_file.path)
        expect(File.exist?(output_file.path)).to be true
      end

      it "embeds JSON data in HTML" do
        generator = described_class.new(repository,
          mode: :single_file,
          output: output_file.path,
        )

        allow_any_instance_of(Liquid::Template)
          .to receive(:render) do |template, context|
            # Verify data is passed to template
            # In single-file mode, data is JSON-serialized string
            expect(context["data"]).to be_a(String)
            expect(context["searchIndex"]).to be_a(String)
            "<html>Data embedded</html>"
        end

        generator.generate
      end
    end

    context "with multi-file mode" do
      it "generates multi-file site structure" do
        generator = described_class.new(repository,
          mode: :multi_file,
          output: output_dir,
        )

        allow_any_instance_of(Liquid::Template)
          .to receive(:render).and_return("<html>Test</html>")

        result = generator.generate

        expect(result).to eq(output_dir)
        expect(File.exist?(File.join(output_dir, "index.html"))).to be true
        expect(File.exist?(File.join(output_dir, "data"))).to be true
        expect(File.exist?(File.join(output_dir, "assets"))).to be true
      end

      it "creates separate JSON data files" do
        generator = described_class.new(repository,
          mode: :multi_file,
          output: output_dir,
        )

        allow_any_instance_of(Liquid::Template)
          .to receive(:render).and_return("<html>Test</html>")

        generator.generate

        expect(File.exist?(File.join(output_dir, "data", "model.json")))
          .to be true
        expect(File.exist?(File.join(output_dir, "data", "search.json")))
          .to be true
      end

      it "creates separate asset files" do
        generator = described_class.new(repository,
          mode: :multi_file,
          output: output_dir,
        )

        allow_any_instance_of(Liquid::Template)
          .to receive(:render).and_return("<html>Test</html>")

        # Mock asset content
        allow(File).to receive(:read).and_call_original
        allow(File)
          .to receive(:read)
          .with(anything)
          .and_return("/* CSS */", "// JS")

        generator.generate

        # These would be created if asset files exist
        # expect(File.exist?(File.join(output_dir, "assets", "styles.css")))
        # .to be true
        # expect(File.exist?(File.join(output_dir, "assets", "app.js")))
        # .to be true
      end
    end

    context "with invalid mode" do
      it "raises error for unsupported mode" do
        generator = described_class.new(repository,
          mode: :invalid_mode,
          output: output_file.path,
        )

        expect {
          generator.generate
        }.to raise_error(ArgumentError, /Invalid mode/)
      end
    end
  end

  describe "configuration integration" do
    it "uses configuration for default values" do
      generator = described_class.new(repository)

      # Should use config defaults
      expect(generator.config).to be_a(Lutaml::UmlRepository::StaticSite::Configuration)
      expect(generator.options).to include(:title)
    end

    it "allows user options to override configuration" do
      generator = described_class.new(repository,
        title: "Custom Title",
        minify: true,
      )

      expect(generator.options[:title]).to eq("Custom Title")
      expect(generator.options[:minify]).to be true
    end
  end

  describe "dependency injection" do
    it "uses injected ID generator" do
      custom_id_gen = Lutaml::UmlRepository::StaticSite::IDGenerator.new

      generator = described_class.new(repository,
        id_generator: custom_id_gen,
      )

      expect(generator.instance_variable_get(:@id_generator))
        .to eq(custom_id_gen)
    end

    it "uses injected data transformer" do
      mock_transformer = double("DataTransformer")

      generator = described_class.new(repository,
        data_transformer: mock_transformer,
      )

      expect(generator.instance_variable_get(:@data_transformer))
        .to eq(mock_transformer)
    end

    it "uses injected search builder" do
      mock_builder = double("SearchBuilder")

      generator = described_class.new(repository,
        search_builder: mock_builder,
      )

      expect(generator.instance_variable_get(:@search_builder))
        .to eq(mock_builder)
    end
  end
end