# frozen_string_literal: true

require "spec_helper"
require "stringio"
require "tempfile"
require "fileutils"

# Issue #584: the validate family fans the per-file parse across the
# ParallelFiles worker pool behind --jobs (default: every core). The
# gate: parallel runs report EXACTLY what a sequential run reports,
# in the same order.
RSpec.describe Expressir::Commands::ValidateLoad do # rubocop:disable RSpec/DescribeClass -- covers both validate commands and Base#jobs_count
  def with_stdout_capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  let(:schema_paths) do
    %w[
      spec/syntax/syntax.exp
      spec/syntax/single.exp
      spec/fixtures/examples/basis_schema.exp
      spec/fixtures/examples/conditions_schema.exp
    ].select { |p| File.exist?(p) }
  end

  def write_dup_anchor_schema(dir)
    path = File.join(dir, "schema.exp")
    File.write(path, <<~EXP)
      SCHEMA sample;
        (*
        [[fig-one]]
        image::fig-one.svg[]
        *)
        ENTITY a; END_ENTITY;
        (*"sample.__fund_cons"
        [[fig-one]]
        image::fig-one.svg[]
        *)
      END_SCHEMA;
    EXP
    path
  end

  describe "validate load" do
    it "reports the same findings for --jobs 1 and the default (all cores)" do
      serial = with_stdout_capture do
        described_class.new({ jobs: 1 }).run(schema_paths)
      end
      parallel = with_stdout_capture do
        described_class.new({}).run(schema_paths)
      end

      expect(parallel).to include("Validation passed for all EXPRESS schemas.")
      expect(parallel).to eq(serial)
    end

    it "reports parse failures without killing the run" do
      bad = "spec/temp-unparseable.exp"
      File.write(bad, "SCHEMA broken;\n  ENTITY e;\n    value : INTEGER;\n  JUNK (((\n")

      output = with_stdout_capture do
        expect do
          described_class.new({}).run([bad] + schema_paths)
        end.to raise_error(Expressir::SchemaValidationError)
      end

      expect(output).to include("Failed to parse: #{bad}")
      expect(output).to include("Validating spec/syntax/syntax.exp")
    end
  end

  describe "validate remarks" do
    it "passes real schemas identically for --jobs 1 and the default" do
      serial = with_stdout_capture do
        Expressir::Commands::ValidateRemarks.new({ jobs: 1 }).run(schema_paths)
      end
      parallel = with_stdout_capture do
        Expressir::Commands::ValidateRemarks.new({}).run(schema_paths)
      end

      expect(parallel).to include("Validation passed")
      expect(parallel).to eq(serial)
    end

    it "raises the same duplicate-anchor violations for --jobs 1 and the default" do
      Dir.mktmpdir("validate-jobs") do |dir|
        path = write_dup_anchor_schema(dir)

        serial_error = nil
        parallel_error = nil

        with_stdout_capture do
          expect do
            Expressir::Commands::ValidateRemarks.new({ jobs: 1 }).run([path])
          end.to raise_error(Expressir::SchemaValidationError) { |e| serial_error = e }
        end
        with_stdout_capture do
          expect do
            Expressir::Commands::ValidateRemarks.new({}).run([path])
          end.to raise_error(Expressir::SchemaValidationError) { |e| parallel_error = e }
        end

        expect(parallel_error.errors).to eq(serial_error.errors)
        expect(parallel_error.errors.join).to include("Duplicate remark block anchor `fig-one`")
      end
    end
  end

  describe "Base#jobs_count" do
    it "defaults to every core" do
      command = described_class.new({})
      expect(command.jobs_count).to eq(Etc.nprocessors)
    end

    it "honors an explicit --jobs 1" do
      command = described_class.new({ jobs: 1 })
      expect(command.jobs_count).to eq(1)
    end
  end
end
