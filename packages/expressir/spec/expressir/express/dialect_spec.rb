# frozen_string_literal: true

require "spec_helper"
require "expressir"
require "yaml"

CHANGES = YAML.load_file(
  Expressir.root_path.join(
    "spec/fixtures/dialects/iso-10303-11-2004-changes.yaml",
  ),
).fetch("changes")

RSpec.describe Expressir::Express::Dialect do
  def notes_for(source, dialect)
    repository = Expressir::Express::Parser.from_exp(source)
    Expressir::Express::Checker.new(
      Expressir::Model::Repository.new(files: [repository]),
      dialect: dialect,
    ).check.notes
  end

  describe ".normalize" do
    it "accepts symbols and strings for both editions" do
      expect(described_class.normalize(:"10303-11:1994"))
        .to eq(:"10303-11:1994")
      expect(described_class.normalize("10303-11:2004"))
        .to eq(:"10303-11:2004")
      expect(described_class.normalize("1994")).to eq(:"10303-11:1994")
      expect(described_class.normalize(nil)).to eq(:"10303-11:2004")
    end

    it "rejects an unknown edition loudly" do
      expect { described_class.normalize("1984") }
        .to raise_error(Expressir::InvalidOptionError, /dialect/)
    end

    it "is accepted by the parser in both editions" do
      source = "SCHEMA s; ENTITY e; x : INTEGER; END_ENTITY; END_SCHEMA;"
      expect do
        Expressir::Express::Parser.from_exp(source, dialect: :"10303-11:1994")
      end.not_to raise_error
      expect do
        Expressir::Express::Parser.from_exp(source, dialect: :"10303-11:2004")
      end.not_to raise_error
    end
  end

  describe "the audited 2004 change list" do
    it "declares only note ids the dialect checker knows" do
      ids = CHANGES.map { |change| change.fetch("note_id").to_sym }
      expect(ids - described_class::NOTE_IDS).to be_empty
      expect(ids).to include(:check_dialect_2004_only,
                             :check_dialect_deprecated)
    end

    it "fires the declared note for every change example under 1994" do
      CHANGES.each do |change|
        next unless change["note_id"] == "check_dialect_2004_only"

        notes = notes_for(change.fetch("example"), :"10303-11:1994")
        expect(notes.map(&:id)).to include(:check_dialect_2004_only),
                                   change.fetch("id")
      end
    end

    it "accepts every 2004 change example under 2004" do
      CHANGES.each do |change|
        next unless change["note_id"] == "check_dialect_2004_only"

        notes = notes_for(change.fetch("example"), :"10303-11:2004")
        expect(notes.map(&:id)).not_to include(:check_dialect_2004_only),
                                       change.fetch("id")
      end
    end

    it "flags deprecated edition-1 syntax under 2004" do
      change = CHANGES.find { |entry| entry["id"] == "inline_subtype_constraint" }
      notes = notes_for(change.fetch("example"), :"10303-11:2004")
      expect(notes.map(&:id)).to include(:check_dialect_deprecated)
      expect(notes.find { |note| note.id == :check_dialect_deprecated }.severity)
        .to eq(:warning)
    end
  end

  describe "edition diagnostics" do
    it "leaves a 1994-era schema clean under both dialects" do
      source = <<~EXPRESS
        SCHEMA legacy;
        ENTITY shape;
          label : STRING;
        END_ENTITY;
        END_SCHEMA;
      EXPRESS
      expect(notes_for(source, :"10303-11:1994").map(&:id)).to be_empty
      expect(notes_for(source, :"10303-11:2004").map(&:id)).to be_empty
    end

    it "reports a file that mixes 2004-only and edition-1 syntax" do
      source = <<~EXPRESS
        SCHEMA mixed;
        TYPE colour = EXTENSIBLE ENUMERATION OF (red);
        END_TYPE;
        ENTITY sup SUPERTYPE OF (ONEOF(a, b));
        END_ENTITY;
        ENTITY a SUBTYPE OF (sup);
        END_ENTITY;
        ENTITY b SUBTYPE OF (sup);
        END_ENTITY;
        END_SCHEMA;
      EXPRESS
      ids = notes_for(source, :"10303-11:1994").map(&:id)
      expect(ids).to include(:check_dialect_2004_only)
      expect(ids).to include(:check_dialect_mixed)
    end
  end

  if ENV["EXPRESSIR_CONFORMANCE"]
    it "runs both dialects over the stepmod resource slice" do
      stepmod = ENV["STEPMOD_DIR"] ||
        File.expand_path("~/src/mn/iso-10303-stepmod")
      corpus = File.join(stepmod, "data/resources")
      skip "stepmod corpus not present at #{corpus}" unless Dir.exist?(corpus)

      files = Dir[File.join(corpus, "**/*.exp")]
        .select { |file| File.size(file) < 250_000 }
      checked = 0
      files.each do |path|
        repository = Expressir::Express::Parser.from_file(path)
        described_class::DIALECTS.each do |dialect|
          Expressir::Express::Checker.new(repository, dialect: dialect).check
        end
        checked += 1
      rescue Parsanol::ParseFailed, Expressir::Express::Error::SchemaParseFailure
        next
      end
      expect(checked).to be > 200
    end
  end
end
