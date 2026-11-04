# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Graphviz formatter registration" do
  it "registers the formatter in the model-driven registry on require" do
    expect(Lutaml::Formatter.all).to include(Lutaml::Formatter::Graphviz)
  end

  it "is found by name" do
    expect(Lutaml::Formatter.find_by_name("graphviz"))
      .to eq(Lutaml::Formatter::Graphviz)
  end

  it "keeps the class-name contract" do
    expect(Lutaml::Formatter::Graphviz.formatter_name).to eq(:graphviz)
    expect(Lutaml::Formatter::Graphviz.name).to eq("Lutaml::Formatter::Graphviz")
  end

  it "formats an empty document to a dot string" do
    skip "GraphViz 'dot' not available" unless system("which dot > /dev/null 2>&1")

    expect(Lutaml::Formatter::Graphviz.format(Lutaml::Lml::Document.new))
      .to be_a(String)
  end

  it "owns the ruby-graphviz dependency" do
    spec = Gem::Specification.load(File.expand_path("../../../lutaml-graphviz.gemspec", __dir__))
    expect(spec.runtime_dependencies.map(&:name)).to include("ruby-graphviz")
  end
end
