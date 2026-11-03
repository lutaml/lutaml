# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tempfile"

# Thor CLI integration for the parity operations (expand/flatten/check).
# Each command writes through the library that's already shipped, so the
# spec only verifies CLI plumbing: -o writes file vs stdout, exit code,
# error propagation.
RSpec.describe Expressir::Cli do
  let(:tmpdirs) { [] }

  let(:support_dir) do
    d = Dir.mktmpdir("exp-cmd-")
    tmpdirs << d
    d
  end

  after { tmpdirs.each { |d| FileUtils.remove_entry(d) } }

  def write_source(name, src)
    path = File.join(support_dir, "#{name}.exp")
    File.write(path, src)
    path
  end

  def capture(args)
    orig_stdout = $stdout
    $stdout = StringIO.new
    begin
      Expressir::Cli.start(args)
      [$stdout.string, 0]
    rescue SystemExit => e
      [$stdout.string, e.status]
    ensure
      $stdout = orig_stdout
    end
  end

  describe "expand" do
    it "concatenates the closure to stdout by default" do
      write_source("support", <<~EXP)
        SCHEMA support;
        TYPE label = STRING; END_TYPE;
        END_SCHEMA;
      EXP
      root = write_source("root", <<~EXP)
        SCHEMA root;
        USE FROM support (label);
        END_SCHEMA;
      EXP

      out, code = capture(["expand", root])
      aggregate_failures do
        expect(code).to eq(0)
        expect(out).to include("Concatenated File produced by")
        expect(out).to include("root")
        expect(out).to include("support")
      end
    end

    it "writes to --output when given" do
      write_source("support", "SCHEMA support;\nTYPE label = STRING; END_TYPE;\nEND_SCHEMA;\n")
      root = write_source("root", <<~EXP)
        SCHEMA root;
        USE FROM support (label);
        END_SCHEMA;
      EXP
      out_path = File.join(support_dir, "concatenated.exp")
      out, code = capture(["expand", "--output", out_path, root])
      aggregate_failures do
        expect(code).to eq(0)
        expect(out).to include(out_path)
        expect(File.read(out_path)).to include("Concatenated File")
      end
    end
  end

  describe "flatten" do
    it "writes a longform schema to --output" do
      write_source("support", <<~EXP)
        SCHEMA support;
        TYPE label = STRING; END_TYPE;
        END_SCHEMA;
      EXP
      root = write_source("root", <<~EXP)
        SCHEMA root;
        USE FROM support (label AS identifier);
        ENTITY e;
          x : identifier;
        END_ENTITY;
        END_SCHEMA;
      EXP
      out_path = File.join(support_dir, "longform.exp")
      out, code = capture(["flatten", "--output", out_path, root])
      aggregate_failures do
        expect(code).to eq(0)
        expect(out).to include(out_path)
        text = File.read(out_path)
        expect(text).to include("SCHEMA root_lf;")
        expect(text).to include("ENTITY e;")
        expect(text).not_to include("USE FROM")
      end
    end
  end

  describe "validate check" do
    it "exits 1 when a check fires" do
      bad = write_source("bad", <<~EXP)
        SCHEMA bad;
        ENTITY e;
          items : LIST [5:2] OF STRING;
        END_ENTITY;
        END_SCHEMA;
      EXP
      _out, code = capture(["validate", "check", bad])
      expect(code).to eq(1)
    end

    it "exits 0 for a clean schema" do
      good = write_source("good", <<~EXP)
        SCHEMA good;
        ENTITY e;
          x : STRING;
        WHERE
          WR1: TRUE;
        END_ENTITY;
        END_SCHEMA;
      EXP
      _out, code = capture(["validate", "check", good])
      expect(code).to eq(0)
    end

    it "emits JSON when --json is passed" do
      bad = write_source("bad", <<~EXP)
        SCHEMA bad;
        ENTITY e;
          items : LIST [5:2] OF STRING;
        END_ENTITY;
        END_SCHEMA;
      EXP
      out, _code = capture(["validate", "check", "--json", bad])
      parsed = JSON.parse(out)
      aggregate_failures do
        expect(parsed["valid"]).to be(false)
        expect(parsed["errors"]).to be_an(Array)
        expect(parsed["errors"]).not_to be_empty
      end
    end

    it "fails on an unparseable file instead of reporting clean (#413)" do
      bad = write_source("bad", "SCHEMA bad;\nENTITY e\n  NOT EXPRESS ((( ;\n")
      out = nil
      code = nil
      expect do
        out, code = capture(["validate", "check", bad])
      end.to output(/failed to parse/).to_stderr
      expect(code).to eq(1)
      expect(out).not_to include("0 error(s)")
    end
  end
end
