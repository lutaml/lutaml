# frozen_string_literal: true

require_relative "../../../spec_helper"
require_relative "../../../support/uml_repository_helpers"

require_relative "../../../../lib/lutaml/uml_repository/static_site/output/strategy"
require_relative "../../../../lib/lutaml/uml_repository/static_site/output/vue_inlined_strategy"
require_relative "../../../../lib/lutaml/uml_repository/static_site/output/multi_file_strategy"
require_relative "../../../../lib/lutaml/uml_repository/static_site/id_generator"
require_relative "../../../../lib/lutaml/uml_repository/static_site/data_transformer"
require_relative "../../../../lib/lutaml/uml_repository/static_site/search_index_builder"
require "tempfile"

RSpec.describe Lutaml::UmlRepository::StaticSite::Output::Strategy do
  it "raises NotImplementedError on #render" do
    strategy = described_class.new("/tmp/out", config: nil)
    expect { strategy.render(nil, nil) }.to raise_error(NotImplementedError)
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Output::VueInlinedStrategy do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:output_file) { Tempfile.new(["test_spa", ".html"]) }
  let(:config) { Lutaml::UmlRepository::StaticSite::Configuration.create_default_configuration }

  after do
    output_file.close
    output_file.unlink
  end

  it "generates a single HTML file with embedded data" do
    transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)
    search_builder = Lutaml::UmlRepository::StaticSite::SearchIndexBuilder.new(repository)
    spa_document = transformer.transform
    search_index = search_builder.build

    strategy = described_class.new(output_file.path, config: config)
    result = strategy.render(spa_document, search_index)

    expect(result).to eq(output_file.path)
    html = File.read(output_file.path)
    expect(html).to start_with("<!DOCTYPE html>")
    expect(html).to include("window.__SPA_DATA__")
    expect(html).to include("<div id=\"app\"></div>")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Output::MultiFileStrategy do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:output_dir) { Dir.mktmpdir }
  let(:config) { Lutaml::UmlRepository::StaticSite::Configuration.create_default_configuration }

  after do
    FileUtils.rm_rf(output_dir)
  end

  it "creates data directory and index.html" do
    transformer = Lutaml::UmlRepository::StaticSite::DataTransformer.new(repository)
    search_builder = Lutaml::UmlRepository::StaticSite::SearchIndexBuilder.new(repository)
    spa_document = transformer.transform
    search_index = search_builder.build

    strategy = described_class.new(output_dir, config: config)
    result = strategy.render(spa_document, search_index)

    expect(result).to eq(output_dir)
    expect(File.exist?(File.join(output_dir, "index.html"))).to be true
    expect(File.exist?(File.join(output_dir, "data", "model.json"))).to be true
    expect(File.exist?(File.join(output_dir, "data", "search.json"))).to be true
  end
end
