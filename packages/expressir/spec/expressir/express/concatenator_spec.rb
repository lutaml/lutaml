# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tempfile"

RSpec.describe Expressir::Express::Concatenator do
  # Realistic-sized fixtures: the Ruby parse path has a small-input
  # USE FROM corruption window (expressir#373; core path unaffected),
  # and corpus-sized schemas sit outside it in every case observed.
  let(:sources) do
    {
      "zeta_schema" => <<~EXP,
        SCHEMA zeta_schema;
        USE FROM beta_schema (beta_entity AS zeta_source_entity);
        TYPE zeta_kind = ENUMERATION OF (zeta_one, zeta_two); END_TYPE;
        ENTITY zeta_entity;
          kind : zeta_kind;
          source : zeta_source_entity;
        END_ENTITY;
        END_SCHEMA;
      EXP
      "beta_schema" => <<~EXP,
        SCHEMA beta_schema;
        TYPE beta_kind = ENUMERATION OF (beta_one, beta_two); END_TYPE;
        ENTITY beta_entity;
          kind : beta_kind;
        END_ENTITY;
        END_SCHEMA;
      EXP
    }
  end

  let(:repository) do
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
    Expressir::Express::Parser.from_files(files.map(&:path), skip_references: true).tap do
      files
    end
  end
  let(:root) { repository.schemas.find { |s| s.id == "zeta_schema" } }

  let(:tempfiles) { [] }

  after { tempfiles.each(&:unlink) }

  it "computes the transitive interface closure, alphabetical" do
    names = described_class.closure(root, repository).map(&:id)
    expect(names).to eq(%w[beta_schema zeta_schema])
  end

  it "writes each source file verbatim behind a name separator" do
    out = StringIO.new(+"")
    described_class.write(out, described_class.closure(root, repository))
    text = out.string
    expect(text).to include("2 Schemata for Concatenated File")
    expect(text).to include("-- BETA_SCHEMA (")
    expect(text).to include("ENTITY beta_entity;")
    expect(text.index("-- BETA_SCHEMA (")).to be < text.index("-- ZETA_SCHEMA (")
  end

  it "round-trips: the artifact parses back containing every closure schema" do
    out_file = Tempfile.new(%w[concat-out .exp])
    out_file.close
    begin
      described_class.call(root, repository, out_file.path)
      begin
        reparsed = Expressir::Express::Parser.from_file(out_file.path, skip_references: true)
      rescue Expressir::Express::Error::SchemaParseFailure
        # Windows CI: the reparse fails at an artifact line whose
        # bytes differ per platform - dump the neighborhood so the
        # next run shows exactly what is there (#487 follow-up).
        File.readlines(out_file.path).each_with_index do |line, i|
          next unless (12..20).cover?(i + 1)

          warn format("artifact:%3d %p", i + 1, line)
        end
        raise
      end
      expect(reparsed.schemas.map(&:id).sort).to eq(%w[beta_schema zeta_schema])
    ensure
      out_file.unlink
    end
  end

  describe "eeng oracle differential", if: ENV.fetch("EENG_PARITY", nil) do
    let(:oracle) do
      File.read(File.expand_path("../../fixtures/eeng/oracle/description-assignment-arm-concatenated.exp", __dir__))
    end

    it "matches --concat_schema for description_assignment ARM" do
      stepmod = ENV["STEPMOD"] || "/Users/mulgogi/src/mn/iso-10303"
      arm = File.join(stepmod, "schemas/modules/description_assignment/arm.exp")
      repository = Expressir::Express::Parser.from_file(arm, skip_references: true)
      root = repository.schemas.first
      schemas = described_class.closure(root, repository)

      oracle_names = oracle.scan(/^-- ([A-Za-z_0-9]+) \(/).flatten
      expect(schemas.map { |s| s.id.upcase }).to eq(oracle_names)

      out = StringIO.new(+"")
      described_class.write(out, schemas)
      oracle_sections = oracle.split(/^-- [A-Za-z_0-9]+ \(.*\)\n--\n/).drop(1)
      our_sections = out.string.split(/^-- [A-Za-z_0-9]+ \(.*\)\n--\n/).drop(1)
      expect(our_sections).to eq(oracle_sections)
    end
  end
end
