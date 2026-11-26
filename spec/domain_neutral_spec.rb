# frozen_string_literal: true

require "spec_helper"

RSpec.describe "lutaml stays domain-neutral" do
  let(:gemspec) do
    Gem::Specification.load(File.expand_path("../lutaml.gemspec", __dir__))
  end

  it "declares no EXPRESS or libffi bridge dependency" do
    names = gemspec.runtime_dependencies.map(&:name)

    expect(names).not_to include("expressir", "fiddle")
  end

  it "ships no Lutaml::Express namespace" do
    expect(Lutaml.autoload?(:Express)).to be_nil
    expect(Lutaml.const_defined?(:Express, false)).to be(false)
  end

  it "ships no EXPRESS parser file" do
    expect(gemspec.files).not_to include(a_string_matching(%r{lib/lutaml/express}))
  end
end
