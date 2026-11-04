# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "SPA artifact determinism" do
  let(:frontend_dist) do
    Lutaml::Jsonschema::Spa::VueInlinedStrategy::FRONTEND_DIST
  end
  let(:fixtures) do
    %w[person.json post.json user.json].map { |name| fixture_path(name) }
  end

  before do
    skip "frontend/dist not built; run `rake frontend:build`" unless
      File.exist?(File.join(frontend_dist, "app.iife.js"))
  end

  def build_into(dir)
    set = Lutaml::Jsonschema::SchemaSet.load_from_files(*fixtures)
    Lutaml::Jsonschema::Spa::Generator.new(set, dir).generate
    File.binread(File.join(dir, "index.html"))
  end

  it "produces byte-identical output for identical inputs" do
    Dir.mktmpdir do |first|
      Dir.mktmpdir do |second|
        expect(build_into(second)).to eq(build_into(first))
      end
    end
  end

  it "re-parses inputs independently and still matches byte-for-byte" do
    Dir.mktmpdir do |first|
      Dir.mktmpdir do |second|
        first_html = build_into(first)
        # New parse of the same files through a fresh SchemaSet.
        second_html = build_into(second)

        expect(second_html.bytesize).to eq(first_html.bytesize)
        expect(second_html).to eq(first_html)
      end
    end
  end

  it "embeds the full schema data and assets in one file" do
    Dir.mktmpdir do |dir|
      html = build_into(dir)

      expect(html).to include("window.SCHEMA_DATA")
      expect(html).to include("<!DOCTYPE html>")
      expect(html).not_to match(%r{<script src=})
      expect(html).not_to match(%r{<link rel="stylesheet" href=})
    end
  end

  it "ships the print stylesheet for the print/PDF path" do
    Dir.mktmpdir do |dir|
      html = build_into(dir)
      inline_css = html[%r{<style>(.*?)</style>}m, 1]

      expect(inline_css).to include("@media print")
    end
  end
end
