# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Commands::Fix do
  def write_schema(dir, name, src)
    path = File.join(dir, name)
    File.write(path, src)
    path
  end

  it "rewrites self-schema references and writes the corrected file" do
    dir = Dir.mktmpdir("fix-")
    @dir = dir
    write_schema(dir, "support_schema.exp", <<~EXP)
      SCHEMA support_schema;
      TYPE label = STRING; END_TYPE;
      END_SCHEMA;
    EXP
    root = write_schema(dir, "root.exp", <<~EXP)
      SCHEMA root_schema;
      USE FROM support_schema (label);
      ENTITY e;
        x : label;
      WHERE
        WR1 : SIZEOF(['ROOT_SCHEMA.LABEL'] * TYPEOF(x)) = 1;
      END_ENTITY;
      END_SCHEMA;
    EXP
    out = File.join(dir, "fixed.exp")

    expect do
      Expressir::Cli.start(["fix", "--output", out, root])
    end.to output(/fixed; written to/).to_stdout

    fixed = File.read(out)
    aggregate_failures do
      expect(fixed).to include("support_schema.LABEL")
      expect(fixed).not_to include("ROOT_SCHEMA.LABEL")
    end
  ensure
    FileUtils.remove_entry(dir) if dir
  end
end
