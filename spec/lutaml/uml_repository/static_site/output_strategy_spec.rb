# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository/static_site/output/strategy"
require "lutaml/uml_repository/static_site/output/vue_inlined_strategy"
require "lutaml/uml_repository/static_site/output/multi_file_strategy"
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

  after do
    output_file.close
    output_file.unlink
  end

  it "raises when frontend assets are not built" do
    config = Lutaml::UmlRepository::StaticSite::Configuration.create_default_configuration
    strategy = described_class.new(output_file.path, config: config)

    expect do
      strategy.render(nil,
                      nil)
    end.to raise_error(RuntimeError, /Frontend asset not found/)
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
