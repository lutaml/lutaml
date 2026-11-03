# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Mapping do
  def write_mapping(body)
    f = Tempfile.new(["mapping", ".yaml"])
    f.write(body)
    f.close
    f
  end

  let(:mapping_yaml) do
    <<~YAML
      ---
      ae:
      - entity: <<express:root_arm.thing,thing>>
        aimelt: <<express:root_mim.thing,thing>>
        aa:
        - attribute: name
          aimelt: root_mim.thing.name
      - entity: <<express:root_arm.gadget,gadget>>
        aimelt: <<express:ghost_schema.gadget,gadget>>
      sc: []
    YAML
  end

  let(:schemas) do
    {
      "root_arm" => <<~EXP,
        SCHEMA root_arm;
        ENTITY thing; a : STRING; END_ENTITY;
        ENTITY gadget; b : STRING; END_ENTITY;
        END_SCHEMA;
      EXP
      "root_mim" => <<~EXP,
        SCHEMA root_mim;
        USE FROM root_arm (thing, gadget);
        ENTITY thing; a : STRING; END_ENTITY;
        END_SCHEMA;
      EXP
    }
  end

  let(:repository) do
    files = schemas.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    repo = Expressir::Express::Parser.from_files(files.map(&:path))
    files.each(&:unlink)
    repo
  end

  let(:document) do
    f = write_mapping(mapping_yaml)
    doc = described_class.load_file(f.path)
    f.unlink
    doc
  end

  it "loads the typed model from the module corpus format" do
    aggregate_failures do
      expect(document.ae.size).to eq(2)
      expect(document.ae.first.aa.first.attribute).to eq("name")
      expect(document.ae.first.aa.first.aimelt).to eq("root_mim.thing.name")
    end
  end

  it "collects express links as schema/item pairs" do
    expect(described_class.links(document)).to include(
      %w[root_arm thing], %w[root_mim thing], %w[ghost_schema gadget]
    )
  end

  it "flags links whose schema or item is unknown" do
    unknown = described_class.unknown_links(document, repository)
    expect(unknown.map { |u| "#{u.schema}.#{u.item}" }).to eq(["ghost_schema.gadget"])
  end

  it "accepts links that resolve against the repository" do
    valid = described_class.links(document).reject do |schema_id, item_id|
      described_class.unknown_links(
        document, repository
      ).any? { |u| u.schema == schema_id && u.item == item_id }
    end
    expect(valid).to include(%w[root_arm thing], %w[root_mim thing])
  end
end
