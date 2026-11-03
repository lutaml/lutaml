# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Expressir::Express::Parser do # compiled schema set
  let(:files) do
    %w[syntax syntax_formatted remark].filter_map do |stem|
      path = File.expand_path("../../syntax/#{stem}.exp", __dir__)
      File.exist?(path) ? path : nil
    end
  end
  let(:set_path) { File.expand_path("tmp_compiled_set.exscs", Dir.tmpdir) }

  before { FileUtils.rm_f(set_path) }

  after { FileUtils.rm_f(set_path) }

  def core_available?
    Expressir::Express::Core::NATIVE_AVAILABLE &&
      Expressir::Core.const_defined?(:Set, false)
  end

  it "warm-loads a byte-identical repository from the artifact" do
    skip "native extension with compiled-set support required" unless core_available?

    cold = described_class.from_files(files, compiled_set: set_path)
    expect(File.exist?(set_path)).to be(true)
    expect(File.exist?("#{set_path}.remarks.json")).to be(true)
    expect(File.exist?("#{set_path}.graph.json")).to be(true)
    cold_hashes = cold.files.map(&:to_hash)

    warm = described_class.from_files(files, compiled_set: set_path)
    expect(warm.files.map(&:to_hash)).to eq(cold_hashes)

    warm_graph = warm.item_graph
    expect(warm_graph).not_to be_nil
    expect(warm_graph.nodes.size).to eq(cold.item_graph.nodes.size)
    expect(warm_graph.subtype_edges.sort).to eq(cold.item_graph.subtype_edges.sort)
    expect(warm_graph.dependencies_of(warm.schemas.first.id))
      .to eq(cold.item_graph.dependencies_of(cold.schemas.first.id))
  end

  it "writes and warm-loads the artifact on the sequential path" do
    skip "native extension with compiled-set support required" unless core_available?

    single = [files.first]
    cold = described_class.from_files(single, compiled_set: set_path)
    expect(File.exist?(set_path)).to be(true)
    expect(File.exist?("#{set_path}.remarks.json")).to be(true)
    expect(File.exist?("#{set_path}.graph.json")).to be(true)
    cold_hashes = cold.files.map(&:to_hash)

    warm = described_class.from_files(single, compiled_set: set_path)
    expect(warm.files.map(&:to_hash)).to eq(cold_hashes)
  end

  it "writes and warm-loads the artifact when the batch is disabled" do
    skip "native extension with compiled-set support required" unless core_available?

    ENV["EXPRESSIR_BATCH"] = "0"
    begin
      cold = described_class.from_files(files, compiled_set: set_path)
      expect(File.exist?(set_path)).to be(true)
      cold_hashes = cold.files.map(&:to_hash)
    ensure
      ENV.delete("EXPRESSIR_BATCH")
    end

    warm = described_class.from_files(files, compiled_set: set_path)
    expect(warm.files.map(&:to_hash)).to eq(cold_hashes)
  end

  it "warns and skips the artifact write when the core extension is absent" do
    skip "native extension present; stubbing exercises the absent path" if core_available?
    set_path = File.expand_path("tmp_compiled_set_absent.exscs", Dir.tmpdir)
    allow(described_class).to receive(:core_set_available?).and_return(false)
    expect do
      described_class.from_files([files.first], compiled_set: set_path)
    end.to output(/compiled-set write to .* skipped.*expressir-core native extension is unavailable/).to_stderr
    expect(File.exist?(set_path)).to be(false)
  ensure
    FileUtils.rm_f(set_path)
  end

  it "rejects an artifact whose sources changed" do
    skip "native extension with compiled-set support required" unless core_available?

    described_class.from_files(files, compiled_set: set_path)
    set = Expressir::Core::Set.open(set_path)
    read_paths = files.to_h { |f| [f, f] }
    expect(set.matches_sources(read_paths)).to be(true)

    original = File.read(files[0])
    File.write(files[0], "#{original}\n-- staleness probe\n")
    begin
      expect(set.matches_sources(read_paths)).to be(false)
    ensure
      File.write(files[0], original)
    end
    expect(set.matches_sources(read_paths)).to be(true)
  end
end
