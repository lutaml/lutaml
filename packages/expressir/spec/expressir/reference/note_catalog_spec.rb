# frozen_string_literal: true

require "spec_helper"
require "expressir"

RSpec.describe Expressir::Reference::NoteCatalog do
  it "catalogs the Checker's note ids" do
    expect(described_class.ids).not_to be_empty
    expect(described_class.ids).to all(match(/\A[a-z0-9_]+\z/))
    expect(described_class.entries.values).to all(be > 0)
  end

  it "keeps the published guide in sync" do
    path = Expressir.root_path.join(
      "docs/_guides/reference/checker-notes.adoc",
    )
    expect(File.read(path)).to eq(described_class.render_adoc)
  end
end
