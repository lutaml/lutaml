# frozen_string_literal: true

require "spec_helper"
require "tempfile"

# M2 slice 2: schemas hydrate per-file, on first touch — rendering one
# schema costs one hydration, not the whole repository.
RSpec.describe Expressir::Express::LazyRepository do
  before do
    skip "native extension not compiled" unless Expressir::Express::Core::NATIVE_AVAILABLE
  end

  # Real files in a kept tmpdir: Tempfile GC-deletes its path, which
  # would make the parity example's eager re-parse hit ENOENT.
  let(:artifact) do
    dir = Dir.mktmpdir("lr")
    paths = Array.new(2) do |i|
      path = File.join(dir, "lr#{i}.exp")
      File.write(path, "SCHEMA lr#{i};\nENTITY e#{i}; x : STRING; END_ENTITY;\nEND_SCHEMA;\n")
      path
    end
    path = File.join(dir, "set.exscs")
    Expressir::Express::Parser.from_files(paths, compiled_set: path)
    read_paths = paths.to_h { |p| [p, p] }
    [path, read_paths, paths]
  end

  def wire_to_source(_paths, read_paths)
    read_paths
  end

  it "lists files without hydrating anything" do
    path, read_paths, paths = artifact
    repo = described_class.new(path, wire_to_source(paths, read_paths))
    aggregate_failures do
      expect(repo.hydration_count).to eq(0)
      expect(repo.wire_paths.size).to eq(2)
      expect(repo.hydration_count).to eq(0)
    end
  end

  it "hydrates a file only when touched, memoized after" do
    path, read_paths, paths = artifact
    repo = described_class.new(path, wire_to_source(paths, read_paths))
    first = repo.files.first

    aggregate_failures do
      expect(first.schemas.first.id).to eq("lr0")
      expect(repo.hydration_count).to eq(1)
      expect(first.schemas.first.id).to eq("lr0")
      expect(repo.hydration_count).to eq(1)
      repo.files.last.schemas.first.id
      expect(repo.hydration_count).to eq(2)
    end
  end

  it "forwards schema access through the wrapper" do
    path, read_paths, paths = artifact
    repo = described_class.new(path, wire_to_source(paths, read_paths))
    file = repo.files.first
    aggregate_failures do
      expect(file.schemas.first.id).to eq("lr0")
      expect(file.__target__).to be_a(Expressir::Model::ExpFile)
    end
  end

  it "to_liquid exposes a lazy drop hydrating per file" do
    path, read_paths, paths = artifact
    repo = described_class.new(path, wire_to_source(paths, read_paths))
    drop = repo.to_liquid

    aggregate_failures do
      expect(repo.hydration_count).to eq(0)
      expect(drop.schemas.size).to eq(2)
      expect(drop.schemas.first.id).to eq("lr0")
      expect(repo.hydration_count).to eq(1)
      drop.schemas.last.id
      expect(repo.hydration_count).to eq(2)
      drop.schemas.first.id
      expect(repo.hydration_count).to eq(2)
    end
  end

  it "renders byte-identical output to the eager path" do
    path, read_paths, paths = artifact
    lazy = described_class.new(path, wire_to_source(paths, read_paths))
    eager = Expressir::Express::Parser.from_files(paths)

    lazy_text = lazy.files.map(&:__target__)
      .flat_map(&:schemas)
      .map { |s| Expressir::Express::Formatter.format(s) }
    eager_text = eager.schemas.map { |s| Expressir::Express::Formatter.format(s) }
    expect(lazy_text).to eq(eager_text)
  end

  it "to_eager returns a full repository" do
    path, read_paths, paths = artifact
    repo = described_class.new(path, wire_to_source(paths, read_paths)).to_eager
    aggregate_failures do
      expect(repo.files.compact.size).to eq(2)
      expect(repo.schemas.map(&:id)).to eq(%w[lr0 lr1])
    end
  end
end
