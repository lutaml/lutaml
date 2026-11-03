require "spec_helper"
require "tempfile"

RSpec.describe Expressir::Express::ParallelFiles do
  let(:syntax_dir) { File.expand_path("../../syntax", __dir__) }
  let(:files) do
    %w[single.exp multiple.exp derived_attribute.exp geometry_schema.exp]
      .map { |f| File.join(syntax_dir, f) }
      .select { |f| File.exist?(f) }
  end

  def parse(paths, max_processes: nil)
    Expressir::Express::Parser.from_files(paths, skip_references: true,
                                                 max_processes: max_processes)
  end

  it "parses files in parallel and returns the same schemas as sequential" do
    skip "needs at least 3 fixture files" if files.size < 3

    parallel = parse(files, max_processes: 4)
    sequential = parse(files, max_processes: 1)

    parallel_ids = parallel.files.flat_map(&:schemas).map(&:id)
    sequential_ids = sequential.files.flat_map(&:schemas).map(&:id)
    expect(parallel_ids).to eq(sequential_ids)
    expect(parallel).to be_a(Expressir::Model::Repository)
    expect(parallel.files.size).to eq(files.size)
  end

  it "produces a deep-equal model to sequential parsing" do
    skip "needs at least 3 fixture files" if files.size < 3

    parallel = parse(files, max_processes: 4)
    sequential = parse(files, max_processes: 1)

    expect(parallel.to_hash).to eq(sequential.to_hash)
  end

  it "preserves file order" do
    skip "needs at least 3 fixture files" if files.size < 3

    repository = parse(files, max_processes: 4)
    expect(repository.files.map { |f| f.schemas.first.id }).to eq(
      parse(files, max_processes: 1).files.map { |f| f.schemas.first.id },
    )
  end

  it "yields progress in original file order" do
    skip "needs at least 3 fixture files" if files.size < 3

    yielded = []
    Expressir::Express::Parser.from_files(files, skip_references: true,
                                                 max_processes: 4) do |file, schemas, error|
      yielded << [File.basename(file), schemas, error]
    end

    expect(yielded.map(&:first)).to eq(files.map { |f| File.basename(f) })
    expect(yielded.map(&:last)).to all(be_nil)
    expect(yielded.map { |_, schemas, _| schemas }).to all(be_an(Array))
  end

  it "yields schemas for each file on the sequential path" do
    yielded = []
    Expressir::Express::Parser.from_files(files.first(2),
                                          skip_references: true) do |file, schemas, error|
      yielded << [File.basename(file), schemas, error]
    end

    expect(yielded.size).to eq(2)
    expect(yielded.map(&:last)).to all(be_nil)
    expect(yielded.first[1]).to be_an(Array)
    expect(yielded.first[1]).to all(be_a(Expressir::Model::Declarations::Schema))
  end

  it "skips files that fail with SchemaParseFailure, like the sequential path" do
    bad = Tempfile.new(%w[bad .exp])
    bad.write("ENTITY broken")
    bad.flush
    paths = files + [bad.path]

    repository = parse(paths, max_processes: 4)
    expect(repository.files.compact.size).to eq(files.size)
    expect(repository.files.last).to be_nil
  end

  it "propagates other errors" do
    missing = files + ["/nonexistent/schema.exp"]

    expect { parse(missing, max_processes: 4) }.to raise_error(Errno::ENOENT)
  end

  it "re-raises SchemaParseFailure in strict mode" do
    unless described_class::FORK_SUPPORTED
      skip "fork is not available on this platform"
    end

    bad = Tempfile.new(%w[bad .exp])
    bad.write("ENTITY broken")
    bad.flush
    paths = files + [bad.path]

    expect do
      described_class.run(
        paths,
        max_processes: 4,
        strict: true,
        parse: lambda do |f|
          Expressir::Express::Parser.from_file(f, skip_references: true)
        end,
      )
    end.to raise_error(Expressir::Express::Error::SchemaParseFailure)
  end

  it "does not fork unless parallelism is explicitly requested" do
    unless described_class::FORK_SUPPORTED
      skip "fork is not available on this platform"
    end

    expect(described_class.sequential?(%w[a.exp b.exp c.exp], nil)).to be(true)
    expect(described_class.sequential?(%w[a.exp b.exp c.exp], 1)).to be(true)
    expect(described_class.sequential?(%w[a.exp b.exp], 4)).to be(true)
    expect(described_class.sequential?(%w[a.exp b.exp c.exp], 4)).to be(false)
  end
end
