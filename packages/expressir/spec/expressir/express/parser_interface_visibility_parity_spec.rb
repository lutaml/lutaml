# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# Cross-file and transitive USE visibility, matching eeng's resolution
# ladder (kernel/find-declaration.lisp: :local → :use-only transitive
# → :use-from, with a cycle guard). TODO.parity-ee/06.
RSpec.describe Expressir::Express::Parser do # interface visibility parity (TODO.parity-ee/06)
  let(:sources) do
    {
      "resource_schema" => <<~EXP,
        SCHEMA resource_schema;
        ENTITY resource_thing;
          name : STRING;
        END_ENTITY;
        END_SCHEMA;
      EXP
      "middle_schema" => <<~EXP,
        SCHEMA middle_schema;
        USE FROM resource_schema (resource_thing);
        ENTITY middle_holder;
          held : resource_thing;
        END_ENTITY;
        END_SCHEMA;
      EXP
      "top_schema" => <<~EXP,
        SCHEMA top_schema;
        USE FROM middle_schema (middle_holder);
        ENTITY top_user;
          u : middle_holder;
          t : resource_thing;
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
    described_class.from_files(files.map(&:path)).tap do
      files
    end
  end
  let(:top_user) do
    repository.schemas
      .find { |s| s.id == "top_schema" }
      .entities.find { |e| e.id == "top_user" }
  end

  let(:tempfiles) { [] }

  after { tempfiles.each(&:unlink) }

  it "resolves a reference to an item USEd from another file" do
    expect(top_user.attributes[0].type.base_path).to include("middle_schema.middle_holder")
  end

  it "resolves a reference to an item visible only transitively through a chain of USEs" do
    expect(top_user.attributes[1].type.base_path).to include("resource_schema.resource_thing")
  end

  it "terminates on interface cycles (USE cycles cannot recurse forever)" do
    # middle_schema USEs resource_schema, and cycle_schema USEs both —
    # a deliberate diamond+cycle; the visited-schema guard must
    # terminate resolution.
    files = sources.map do |name, source|
      f = Tempfile.new(["#{name}2", ".exp"])
      f.write(source)
      f.close
      f
    end
    cycle = Tempfile.new(%w[cycle .exp])
    cycle.write("SCHEMA cycle_schema;\nUSE FROM middle_schema (middle_holder);\nUSE FROM resource_schema (resource_thing);\nENTITY cyc;\n  x : resource_thing;\nEND_ENTITY;\nEND_SCHEMA;\n")
    cycle.close
    begin
      repo = described_class.from_files(files.map(&:path) + [cycle.path])
      cyc = repo.schemas.find { |s| s.id == "cycle_schema" }
      expect(cyc.entities.first.attributes[0].type.base_path).to include("resource_schema.resource_thing")
    ensure
      (files + [cycle]).each(&:unlink)
    end
  end
end
