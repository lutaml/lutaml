# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# Review findings #397 and #406.
RSpec.describe Expressir::Express::Parser do # review findings #397/#406
  def write_sources(sources)
    sources.map do |name, source|
      f = Tempfile.new(["#{name}1", ".exp"])
      f.write(source)
      f.close
      f
    end
  end

  describe "#406 parse failures do not crash Repository#schemas" do
    it "reports the schemas that did parse and skips the failed file" do
      file = Tempfile.new(["malformed1", ".exp"])
      file.write("SCHEMA broken; ENTITY e STRING END_SCHEMA;\n")
      file.close
      good = Tempfile.new(["good1", ".exp"])
      good.write("SCHEMA good;\nENTITY e;\n  x : STRING;\nEND_ENTITY;\nEND_SCHEMA;\n")
      good.close

      repo = described_class.from_files([file.path, good.path])
      aggregate_failures do
        expect(repo.schemas.map(&:id)).to eq(["good"])
        expect(repo.files.count(nil)).to eq(1)
      end
      file.unlink
      good.unlink
    end
  end

  describe "#397 mutual USE FROM with item lists" do
    it "builds the repository without recursing forever" do
      files = write_sources(
        "a" => <<~EXP,
          SCHEMA a;
          USE FROM b (y);
          ENTITY x;
            n : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (x);
          ENTITY y;
            m : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      repo = described_class.from_files(files.map(&:path),
                                        skip_references: true)
      aggregate_failures do
        expect(repo.schemas.map { |s| s.id.downcase })
          .to contain_exactly("a", "b")
      end
      files.each(&:unlink)
    end

    it "exposes interfaced items across the mutual dependency" do
      files = write_sources(
        "a" => <<~EXP,
          SCHEMA a;
          USE FROM b (y);
          ENTITY x;
            n : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
        "b" => <<~EXP,
          SCHEMA b;
          USE FROM a (x);
          ENTITY y;
            m : STRING;
          END_ENTITY;
          END_SCHEMA;
        EXP
      )
      repo = described_class.from_files(files.map(&:path),
                                        skip_references: true)
      schema_a = repo.schemas.find { |s| s.id.downcase == "a" }
      children = schema_a.children
      expect(children.map(&:id)).to include("x", "y")
      files.each(&:unlink)
    end
  end
end
