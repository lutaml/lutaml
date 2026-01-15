# frozen_string_literal: true

ENV['APP_ENV'] = 'test'

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
      File.join(__dir__, "../../../../examples/lur/basic.lur")
    )
    repo = Lutaml::UmlRepository::Repository.from_file(lur_path)
    app.send(:set, :repository, repo)
  end

  describe "GET /" do
    it "returns the index page" do
      get "/"
      expect(last_response).to be_ok
      expect(last_response.body).to include("UML Repository Explorer")
    end
  end

  describe "GET /api/data" do
    it "returns data as JSON" do
      get "/api/data"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)

      expect(data).to have_key("metadata")
      expect(data["metadata"]).to have_key("statistics")
      expect(data["metadata"]["statistics"]).to have_key("packages")
      expect(data["metadata"]["statistics"]).to have_key("classes")
      expect(data["metadata"]["statistics"]).to have_key("associations")
      expect(data["metadata"]["statistics"]).to have_key("attributes")
      expect(data["metadata"]["statistics"]).to have_key("operations")
      expect(data["metadata"]["statistics"]["packages"]).to eq(42)
      expect(data["metadata"]["statistics"]["classes"]).to eq(65)
    end
  end

  # not yet implemented
  describe "GET /api/packages/:id" do
    xit "returns package as JSON" do
      get "/api/packages/pkg_5b44a156"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)
      expect(data["name"]).to eq("ModelRoot")
    end
  end

  describe "GET /api/search/index" do
    it "returns search results as JSON" do
      get "/api/search/index"
      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")

      data = JSON.parse(last_response.body)

      expect(data).to have_key("documentStore")
      expect(data["documentStore"]).to be_a(Array)
      expect(data["documentStore"][0]).to have_key("id")
      expect(data["documentStore"][0]).to have_key("type")
      expect(data["documentStore"][0]).to have_key("entityType")
      expect(data["documentStore"][0]).to have_key("entityId")
      expect(data["documentStore"][0]).to have_key("name")
      expect(data["documentStore"][0]).to have_key("qualifiedName")
      expect(data["documentStore"][0]).to have_key("package")
      expect(data["documentStore"][0]).to have_key("content")
      expect(data["documentStore"][0]).to have_key("boost")
    end
  end
end