# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../../lib/lutaml/uml_repository/exporters/" \
                 "markdown_exporter"

RSpec.describe Lutaml::UmlRepository::Exporters::Markdown::ClassPageBuilder do
  let(:repository) do
    Lutaml::UmlRepository::Repository.new(
      document: create_resolution_test_document,
    )
  end
  let(:link_resolver) do
    Lutaml::UmlRepository::Exporters::Markdown::LinkResolver.new(
      repository.indexes,
    )
  end
  let(:builder) { described_class.new(repository, link_resolver) }
  let(:alpha) { repository.find_class("ModelRoot::PkgA::Alpha") }
  let(:page) { builder.build(alpha, "ModelRoot::PkgA::Alpha") }

  describe "attribute type rendering" do
    it "links a resolved class type but code-spans a primitive",
       :aggregate_failures do
      # refSame : Beta resolves to ModelRoot::PkgA::Beta -> markdown link
      expect(page).to match(%r{\[Beta\]\(\.\./classes/[^)]+\.md\)})
      # refPrimitive : String stays a plain code span (never a link)
      expect(page).to include("`String`")
      expect(page).not_to include("[String](")
    end
  end
end
