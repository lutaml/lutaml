# frozen_string_literal: true

ENV["APP_ENV"] = "test"

require "spec_helper"
require "rack/test"
require_relative "../../../../lib/lutaml/uml_repository/web_ui/app"

RSpec.describe Lutaml::Xmi::WebUi::App do
  include Rack::Test::Methods

  def app
    Lutaml::Xmi::WebUi::App
  end

  before do
    lur_path = File.expand_path(
      File.join(__dir__, "../../../../examples/lur/basic.lur"),
    )
    repo = Lutaml::UmlRepository::Repository.from_file(lur_path)
    app.send(:set, :repository, repo)
  end

  describe "GET /" do
    it "returns the index page" do
      get "/"
      expect(last_response).to be_ok
    end

    it "includes UML Repository Explorer" do
      get "/"
      expect(last_response.body).to include("UML Repository Explorer")
    end
  end

  describe "GET /api/data" do
    let(:data) { JSON.parse(get("/api/data").body) }

    it "returns data as JSON" do
      get "/api/data"
      expect(last_response).to be_ok
    end

    it { expect(get("/api/data").content_type).to include("application/json") }
    it { expect(data).to have_key("metadata") }
    it { expect(data["metadata"]).to have_key("statistics") }
    it { expect(data["metadata"]["statistics"]).to have_key("packages") }
    it { expect(data["metadata"]["statistics"]).to have_key("classes") }
    it { expect(data["metadata"]["statistics"]).to have_key("associations") }
    it { expect(data["metadata"]["statistics"]).to have_key("attributes") }
    it { expect(data["metadata"]["statistics"]).to have_key("operations") }
    it { expect(data["metadata"]["statistics"]["packages"]).to eq(42) }
    it { expect(data["metadata"]["statistics"]["classes"]).to eq(65) }
  end

  describe "GET /api/packages/:id" do
    let(:data) { JSON.parse(get("/api/packages/pkg_5b44a156").body) }

    it "returns package as JSON" do
      get "/api/packages/pkg_5b44a156"
      expect(last_response).to be_ok
    end

    it {
      expect(get("/api/packages/pkg_5b44a156").content_type).to include("application/json")
    }

    it { expect(data["name"]).to eq("Model") }
  end

  describe "GET /api/search/index" do
    let(:data) { JSON.parse(get("/api/search/index").body) }

    it "returns search results as JSON" do
      get "/api/search/index"
      expect(last_response).to be_ok
    end

    it {
      expect(get("/api/search/index").content_type).to include("application/json")
    }

    it { expect(data).to have_key("documentStore") }
    it { expect(data["documentStore"]).to be_a(Array) }
    it { expect(data["documentStore"][0]).to have_key("id") }
    it { expect(data["documentStore"][0]).to have_key("type") }
    it { expect(data["documentStore"][0]).to have_key("entityType") }
    it { expect(data["documentStore"][0]).to have_key("entityId") }
    it { expect(data["documentStore"][0]).to have_key("name") }
    it { expect(data["documentStore"][0]).to have_key("qualifiedName") }
    it { expect(data["documentStore"][0]).to have_key("package") }
    it { expect(data["documentStore"][0]).to have_key("content") }
    it { expect(data["documentStore"][0]).to have_key("boost") }
  end
end
