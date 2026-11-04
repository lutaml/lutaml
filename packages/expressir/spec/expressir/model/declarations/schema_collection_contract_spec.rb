# frozen_string_literal: true

require "expressir"

RSpec.describe Expressir::Model::Declarations::Schema do
  let(:schema) { described_class.new }

  it "reads absent collections as [] on a fresh model" do
    expect(schema.rules).to eq([])
    expect(schema.constants).to eq([])
    expect(schema.entities).to eq([])
    expect(schema.interfaces).to eq([])
  end

  it "reads absent collections as [] on a fresh nested element" do
    entity = Expressir::Model::Declarations::Entity.new
    expect(entity.subtype_of).to eq([])
    expect(entity.where_rules).to eq([])
  end

  it "replays a serialized model with [] for absent clauses" do
    schema.id = "replay_schema"
    json = schema.to_json
    replayed = described_class.from_json(json)
    expect(replayed.rules).to eq([])
    expect(replayed.constants).to eq([])
  end

  it "preserves an explicit null collection as nil" do
    from_null = described_class.from_json(
      %({"id": "x", "rules": null}),
    )
    expect(from_null.rules).to be_nil
  end

  it "keeps parse-path output unchanged" do
    require "tmpdir"
    src = <<~EXP
      SCHEMA contract_schema;
        ENTITY e1;
          name : STRING;
        END_ENTITY;
      END_SCHEMA;
    EXP
    file = File.join(Dir.mktmpdir, "contract.exp")
    File.write(file, src)
    schema = Expressir::Express::Parser.from_file(file).schemas.first
    expect(schema.rules).to eq([])
    expect(schema.functions).to eq([])
    expect(schema.entities.first.subtype_of).to eq([])
  end
end
