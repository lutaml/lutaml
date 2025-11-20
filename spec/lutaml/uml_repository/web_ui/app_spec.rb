# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require_relative "../../../../lib/lutaml/uml_repository/web_ui/app"

RSpec.describe Lutaml::Xmi::WebUi::App do
  include Rack::Test::Methods

  def app
    Lutaml::Xmi::WebUi::App
  end

  let(:repository) { instance_double("Lutaml::UmlRepository::Repository") }
  let(:indexes) { { classes: {}, package_to_path: {} } }
  let(:statistics) do
    {
      total_packages: 3,
      total_classes: 10,
      total_associations: 5,
      total_diagrams: 2
    }
  end

  before do
    app.set :repository, repository
    allow(repository).to receive(:indexes).and_return(indexes)
    allow(repository).to receive(:statistics).and_return(statistics)
    allow(repository).to receive(:package_tree).and_return(nil)
  end

  describe "GET /" do
    it "returns the index page" do
      get "/"
      expect(last_response).to be_ok
      expect(last_response.body).to include("UML Repository Explorer")
    end
  end

  describe "GET /api/statistics" do
    it "returns statistics as JSON" do
      get "/api/statistics"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)
      expect(data["total_classes"]).to eq(10)
      expect(data["total_packages"]).to eq(3)
    end
  end

  describe "GET /api/packages/tree" do
    let(:tree) do
      {
        name: "ModelRoot",
        path: "ModelRoot",
        classes_count: 5,
        children: []
      }
    end

    before do
      allow(repository).to receive(:package_tree).and_return(tree)
    end

    it "returns package tree as JSON" do
      get "/api/packages/tree"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)
      expect(data["tree"]["name"]).to eq("ModelRoot")
    end
  end

  describe "GET /api/search" do
    let(:search_results) do
      {
        class: [],
        attribute: [],
        association: []
      }
    end

    before do
      allow(repository).to receive(:search).and_return(search_results)
    end

    it "returns search results as JSON" do
      get "/api/search", q: "Building"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)
      expect(data["query"]).to eq("Building")
      expect(data["results"]).to be_a(Hash)
    end

    it "returns 400 without query parameter" do
      get "/api/search"
      expect(last_response.status).to eq(400)
    end
  end
end