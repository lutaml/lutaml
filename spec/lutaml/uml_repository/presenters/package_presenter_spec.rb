# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/presenters/package_presenter"
require_relative "../../../../lib/lutaml/uml/package"

RSpec.describe Lutaml::UmlRepository::Presenters::PackagePresenter do
  let(:package_element) do
    Lutaml::Uml::Package.new(
      name: "Models",
      xmi_id: "PKG_001",
    )
  end

  let(:presenter) { described_class.new(package_element) }

  describe "#to_text" do
    it "generates formatted text output", :aggregate_failures do
      text = presenter.to_text
      expect(text).to include("Package: Models")
      expect(text).to include("=" * 50)
      expect(text).to include("Name:        Models")
      expect(text).to include("XMI ID:      PKG_001")
    end

    it "handles package without xmi_id" do
      package_element.xmi_id = nil
      expect(presenter.to_text).not_to include("XMI ID:")
    end
  end

  describe "#to_hash" do
    it "generates structured hash", :aggregate_failures do
      hash = presenter.to_hash
      expect(hash[:type]).to eq("Package")
      expect(hash[:name]).to eq("Models")
      expect(hash[:xmi_id]).to eq("PKG_001")
    end

    it "excludes xmi_id when nil" do
      package_element.xmi_id = nil
      expect(presenter.to_hash).not_to have_key(:xmi_id)
    end
  end

  describe "factory registration" do
    it "registers with PresenterFactory" do
      factory = Lutaml::UmlRepository::Presenters::PresenterFactory
      expect(factory.presenters[Lutaml::Uml::Package]).to eq(described_class)
    end
  end

  describe "inheritance" do
    it "inherits from ElementPresenter" do
      expect(described_class.superclass)
        .to eq(Lutaml::UmlRepository::Presenters::ElementPresenter)
    end

    it "exposes element attribute" do
      expect(presenter.element).to eq(package_element)
    end
  end
end
