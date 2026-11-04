# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# M2: lazy access over a compiled set — nothing hydrates until a
# specific file is asked for.
RSpec.describe Expressir::Express::Core do
  before do
    skip "native extension not available" unless described_class::NATIVE_AVAILABLE
  end

  let(:artifact) do
    files = Array.new(2) do |i|
      f = Tempfile.new(["lazy#{i}", ".exp"])
      f.write("SCHEMA lazy#{i};\nENTITY e#{i}; x : STRING; END_ENTITY;\nEND_SCHEMA;\n")
      f.close
      f
    end
    path = File.join(Dir.mktmpdir("lazy"), "set.exscs")
    Expressir::Express::Parser.from_files(files.map(&:path), compiled_set: path)
    files.each(&:unlink)
    path
  end

  it "lists wire paths without hydrating models" do
    set = described_class.lazy_set(artifact)
    paths = set.wire_paths
    aggregate_failures do
      expect(paths.size).to eq(2)
      expect(paths).to all(match(/\.exp\z/))
    end
  end

  it "hydrates one file on demand" do
    set = described_class.lazy_set(artifact)
    target = set.wire_paths.first
    _wire_path, model = set.hydrate_one(target)
    expect(model.schemas.first.id).to eq("lazy0")
  end

  it "raises for a wire path outside the set" do
    set = described_class.lazy_set(artifact)
    expect { set.hydrate_one("/nonexistent.exp") }
      .to raise_error(RuntimeError, /not in compiled set/)
  end
end
