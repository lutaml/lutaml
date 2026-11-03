# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "yaml"

# YAML inputs are derived at runtime from the existing JSON fixtures, so
# no YAML schema files are shipped.
RSpec.describe Lutaml::Jsonschema::SourceFile do
  let(:fixtures) { File.expand_path("../fixtures", __dir__) }

  def fixture_hash(name)
    JSON.parse(File.read(File.join(fixtures, name)))
  end

  def write(dir, name, content)
    File.join(dir, name).tap { |path| File.write(path, content) }
  end

  def adoc(set)
    Lutaml::Jsonschema::Exports::Adoc.new(set).render
  end

  it "exports YAML-encoded schemas exactly like the JSON source" do
    json_path = File.join(fixtures, "person.json")
    expected = adoc(Lutaml::Jsonschema::SchemaSet.load_from_files(json_path))

    Dir.mktmpdir do |dir|
      %w[person.yaml person.yml].each do |file|
        path = write(dir, file, YAML.dump(fixture_hash("person.json")))
        set = Lutaml::Jsonschema::SchemaSet.load_from_files(path)

        expect(adoc(set)).to eq(expected)
        expect(set.source_json("person"))
          .to eq(JSON.pretty_generate(fixture_hash("person.json")))
      end
    end
  end

  it "keeps JSON source bytes unchanged" do
    path = File.join(fixtures, "person.json")
    set = Lutaml::Jsonschema::SchemaSet.load_from_files(path)

    expect(set.source_json("person")).to eq(File.read(path, encoding: "utf-8"))
  end

  it "discovers JSON and YAML files in a directory" do
    Dir.mktmpdir do |dir|
      write(dir, "a.json", JSON.generate(fixture_hash("user.json")))
      write(dir, "b.yaml", YAML.dump(fixture_hash("post.json")))
      write(dir, "c.yml", YAML.dump(fixture_hash("person.json")))
      write(dir, "notes.txt", "not a schema")

      set = Lutaml::Jsonschema::SchemaSet.load_from_directory(dir)

      expect(set.schemas.keys).to contain_exactly("a", "b", "c")
    end
  end

  it "loads local YAML file references and matches SchemaStore" do
    Dir.mktmpdir do |dir|
      person = fixture_hash("cross_ref_person.json")
      person["properties"]["home"]["$ref"] = "./cross_ref_base.yaml"
      person_path = write(dir, "cross_ref_person.yaml", YAML.dump(person))
      write(dir, "cross_ref_base.yaml",
            YAML.dump(fixture_hash("cross_ref_base.json")))

      set = Lutaml::Jsonschema::SchemaSet.load_from_files(person_path)
      base = set.resolve_ref("./cross_ref_base.yaml",
                             set.schemas["cross_ref_person"])
      expect(base&.dollar_id).to eq("cross_ref_base")

      store = Lutaml::Jsonschema::SchemaStore.load_from_files(person_path,
                                                              base_dir: dir)
      expect(store.source_json("cross_ref_person"))
        .to eq(set.source_json("cross_ref_person"))
      expect(store.schemas["cross_ref_person"].title).to eq("Person")
      store_base = store.resolve_ref("./cross_ref_base.yaml",
                                     store.schemas["cross_ref_person"])
      expect(store_base&.dollar_id).to eq("cross_ref_base")
    end
  end

  {
    "object tags" => "title: !ruby/object:Object {}\n",
    "aliases" => "a: &x {type: string}\nb: *x\n",
    "non-string keys" => "properties:\n  1: {type: string}\n",
    "unquoted dates" => "default: 2024-01-01\n",
  }.each do |label, yaml|
    it "rejects #{label}" do
      Dir.mktmpdir do |dir|
        path = write(dir, "bad.yaml", yaml)

        expect { Lutaml::Jsonschema::SchemaSet.load_from_files(path) }
          .to raise_error(described_class::InvalidYamlError)
      end
    end
  end
end
