# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/generator"
require "lutaml/uml_repository/static_site/output/vue_inlined_strategy"
require "lutaml/uml_repository/static_site/output/multi_file_strategy"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::StaticSite::Generator do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:output_file) { Tempfile.new(["test_output", ".html"]) }
  let(:output_dir) { Dir.mktmpdir }

  after do
    output_file.close
    output_file.unlink
    FileUtils.rm_rf(output_dir)
  end

  describe "#initialize" do
    it "initializes with repository and options", :aggregate_failures do
      generator = described_class.new(repository, output: output_file.path)

      expect(generator.repository).to eq(repository)
      expect(generator.options).to be_a(Hash)
    end

    it "loads configuration" do
      generator = described_class.new(repository)

      expect(generator.config).to be_a(Lutaml::UmlRepository::StaticSite::Configuration)
    end

    it "creates data transformer and search builder", :aggregate_failures do
      generator = described_class.new(repository)

      expect(generator.data_transformer).to be_a(Lutaml::UmlRepository::StaticSite::DataTransformer)
      expect(generator.search_builder).to be_a(Lutaml::UmlRepository::StaticSite::SearchIndexBuilder)
    end

    it "accepts custom configuration" do
      custom_config = Lutaml::UmlRepository::StaticSite::Configuration.create_default_configuration
      generator = described_class.new(repository, config: custom_config)

      expect(generator.config).to eq(custom_config)
    end

    it "accepts injected dependencies", :aggregate_failures do
      custom_id_gen = Lutaml::UmlRepository::StaticSite::IdGenerator.new
      custom_transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)
      custom_builder = Lutaml::UmlRepository::StaticSite::SearchIndexBuilder.new(repository)

      generator = described_class.new(repository,
                                      id_generator: custom_id_gen,
                                      data_transformer: custom_transformer,
                                      search_builder: custom_builder)

      expect(generator.id_generator).to eq(custom_id_gen)
      expect(generator.data_transformer).to eq(custom_transformer)
      expect(generator.search_builder).to eq(custom_builder)
    end
  end

  describe "#generate" do
    context "with single-file mode" do
      it "delegates to the output strategy" do
        custom_strategy_class = Class.new(
          Lutaml::UmlRepository::StaticSite::Output::Strategy,
        ) do
          def render(_spa_document, _search_index)
            output_path
          end
        end

        generator = described_class.new(repository,
                                        mode: :single_file,
                                        output: output_file.path,
                                        output_strategy: custom_strategy_class)
        result = generator.generate

        expect(result).to eq(output_file.path)
      end
    end

    context "with multi-file mode" do
      it "generates multi-file output", :aggregate_failures do
        custom_strategy_class = Class.new(
          Lutaml::UmlRepository::StaticSite::Output::Strategy,
        ) do
          def render(_doc, _idx)
            FileUtils.mkdir_p(output_path)
            File.write(File.join(output_path, "index.html"),
                       "<html>test</html>")
            output_path
          end
        end

        generator = described_class.new(repository,
                                        mode: :multi_file,
                                        output: output_dir,
                                        output_strategy: custom_strategy_class)
        result = generator.generate

        expect(result).to eq(output_dir)
        expect(File.exist?(File.join(output_dir, "index.html"))).to be true
      end
    end

    context "with custom output strategy" do
      it "uses the injected strategy class" do
        custom_class = Class.new(Lutaml::UmlRepository::StaticSite::Output::Strategy) do
          def render(_doc, _idx)
            output_path
          end
        end

        generator = described_class.new(repository,
                                        output: "/tmp/custom.html",
                                        output_strategy: custom_class)
        result = generator.generate

        expect(result).to eq("/tmp/custom.html")
      end
    end

    context "with invalid mode" do
      it "raises error during initialization for unsupported mode" do
        expect do
          described_class.new(repository,
                              mode: :invalid_mode,
                              output: output_file.path)
        end.to raise_error(ArgumentError, /Invalid mode/)
      end
    end
  end

  describe "configuration integration" do
    it "uses configuration for default values", :aggregate_failures do
      generator = described_class.new(repository)

      expect(generator.config).to be_a(Lutaml::UmlRepository::StaticSite::Configuration)
      expect(generator.options).to include(:title)
    end

    it "allows user options to override configuration", :aggregate_failures do
      generator = described_class.new(repository,
                                      title: "Custom Title",
                                      minify: true)

      expect(generator.options[:title]).to eq("Custom Title")
      expect(generator.options[:minify]).to be true
    end
  end

  describe "dependency injection" do
    it "uses injected ID generator" do
      custom_id_gen = Lutaml::UmlRepository::StaticSite::IdGenerator.new

      generator = described_class.new(repository,
                                      id_generator: custom_id_gen)

      expect(generator.id_generator).to eq(custom_id_gen)
    end

    it "uses injected data transformer" do
      custom_transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)

      generator = described_class.new(repository,
                                      data_transformer: custom_transformer)

      expect(generator.data_transformer).to eq(custom_transformer)
    end

    it "uses injected search builder" do
      custom_builder = Lutaml::UmlRepository::StaticSite::SearchIndexBuilder.new(repository)

      generator = described_class.new(repository,
                                      search_builder: custom_builder)

      expect(generator.search_builder).to eq(custom_builder)
    end
  end
end
