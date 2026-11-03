# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Jsonschema::Spa::SpaLink do
  describe "JSON serialization" do
    it "serializes all fields" do
      link = described_class.new(
        title: "Create User",
        description: "Creates a new user",
        http_method: "POST",
        href: "/users",
        rel: "create",
      )
      parsed = JSON.parse(link.to_json)
      expect(parsed["title"]).to eq("Create User")
      expect(parsed["description"]).to eq("Creates a new user")
      expect(parsed["method"]).to eq("POST")
      expect(parsed["href"]).to eq("/users")
      expect(parsed["rel"]).to eq("create")
    end

    it "omits nil fields" do
      link = described_class.new(href: "/items")
      parsed = JSON.parse(link.to_json)
      expect(parsed["href"]).to eq("/items")
      expect(parsed).not_to have_key("title")
      expect(parsed).not_to have_key("method")
    end

    it "round-trips through JSON" do
      link = described_class.new(
        title: "Search",
        http_method: "GET",
        href: "/search",
        rel: "search",
        description: "Full-text search",
      )
      reparsed = described_class.from_json(link.to_json)
      expect(reparsed.title).to eq("Search")
      expect(reparsed.http_method).to eq("GET")
      expect(reparsed.href).to eq("/search")
      expect(reparsed.rel).to eq("search")
      expect(reparsed.description).to eq("Full-text search")
    end
  end
end
