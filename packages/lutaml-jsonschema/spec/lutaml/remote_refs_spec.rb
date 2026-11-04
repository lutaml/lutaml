# frozen_string_literal: true

require "spec_helper"
require "yeptris"
require "tmpdir"
require "fileutils"
require "uri"

RSpec.describe "Remote HTTP(S) $ref resolution" do
  def write_fixture(dir, name, hash)
    path = File.join(dir, name)
    File.write(path, Yeptris::JSON.dump(hash))
    path
  end

  # A file-backed transport standing in for HTTP: maps
  # https://example.com/<name>.json to <dir>/<name>.json.
  def file_loader(dir)
    lambda do |uri|
      File.read(File.join(dir, File.basename(URI(uri).path)))
    end
  end

  def failing_loader
    ->(_uri) { raise "network must not be reached" }
  end

  let(:remote_hash) do
    {
      "$id" => "https://example.com/shared.json",
      "type" => "object",
      "definitions" => { "tag" => { "type" => "string" } },
      "properties" => { "tag" => { "$ref" => "#/definitions/tag" } },
    }
  end

  let(:local_hash) do
    {
      "type" => "object",
      "properties" => {
        "shared" => { "$ref" => "https://example.com/shared.json" },
        "tag" => { "$ref" => "https://example.com/shared.json#/definitions/tag" },
      },
    }
  end

  it "does not fetch unless remote access is enabled" do
    Dir.mktmpdir do |dir|
      write_fixture(dir, "shared.json", remote_hash)
      set = Lutaml::Jsonschema::SchemaSet.new(remote_loader: file_loader(dir))
      set.add("demo",
              Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(local_hash)))

      expect(set.resolve_ref("https://example.com/shared.json")).to be_nil
      expect(set.remote_errors.values.join).to include("remote refs disabled")
    end
  end

  it "resolves a whole-document remote ref when allowed" do
    Dir.mktmpdir do |dir|
      write_fixture(dir, "shared.json", remote_hash)
      set = Lutaml::Jsonschema::SchemaSet.new(allow_remote: true,
                                              remote_loader: file_loader(dir))
      set.add("demo",
              Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(local_hash)))

      resolved = set.resolve_ref("https://example.com/shared.json")
      expect(resolved).to be_a(Lutaml::Jsonschema::Schema)
      expect(resolved.dollar_id).to eq("https://example.com/shared.json")
      expect(set.schemas).to include("shared")
    end
  end

  it "returns the same schema object for repeated remote refs" do
    Dir.mktmpdir do |dir|
      write_fixture(dir, "shared.json", remote_hash)
      set = Lutaml::Jsonschema::SchemaSet.new(allow_remote: true,
                                              remote_loader: file_loader(dir))

      first = set.resolve_ref("https://example.com/shared.json")
      second = set.resolve_ref("https://example.com/shared.json")
      expect(first).to equal(second)
    end
  end

  it "resolves pointer and anchor fragments inside the remote document" do
    Dir.mktmpdir do |dir|
      remote = remote_hash.merge("$anchor" => "the-tag",
                                 "definitions" => {
                                   "tag" => { "type" => "string",
                                              "$anchor" => "tag-anchor" },
                                 })
      write_fixture(dir, "shared.json", remote)
      set = Lutaml::Jsonschema::SchemaSet.new(allow_remote: true,
                                              remote_loader: file_loader(dir))

      pointer = set.resolve_ref("https://example.com/shared.json#/definitions/tag")
      anchor = set.resolve_ref("https://example.com/shared.json#tag-anchor")

      expect(pointer&.type).to eq("string")
      expect(anchor&.type).to eq("string")
    end
  end

  it "caches documents on disk and serves later runs offline" do
    Dir.mktmpdir do |dir|
      cache_dir = File.join(dir, "cache")
      write_fixture(dir, "shared.json", remote_hash)

      online = Lutaml::Jsonschema::SchemaSet.new(
        allow_remote: true, remote_cache_dir: cache_dir,
        remote_loader: file_loader(dir)
      )
      expect(online.resolve_ref("https://example.com/shared.json")).to be_a(
        Lutaml::Jsonschema::Schema,
      )
      expect(Dir.glob(File.join(cache_dir, "*.json")).length).to eq(1)

      offline = Lutaml::Jsonschema::SchemaSet.new(
        allow_remote: false, remote_cache_dir: cache_dir,
        remote_loader: failing_loader
      )
      offline.add("demo",
                  Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(local_hash)))

      expect(offline.resolve_ref("https://example.com/shared.json")).to be_a(
        Lutaml::Jsonschema::Schema,
      )
      expect(offline.remote_errors).to be_empty
    end
  end

  it "flags unreachable remote refs during validation" do
    set = Lutaml::Jsonschema::SchemaSet.new(remote_loader: failing_loader)
    set.add("demo",
            Lutaml::Jsonschema::Schema.from_json(Yeptris::JSON.dump(local_hash)))

    expect(set.validation_errors).to(
      include(/unresolvable \$ref 'https:\/\/example\.com\/shared\.json'/),
    )
  end
end
