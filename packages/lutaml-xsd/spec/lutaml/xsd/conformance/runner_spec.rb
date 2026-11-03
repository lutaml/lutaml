# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd"
require "lutaml/xsd/conformance/runner"

RSpec.describe Lutaml::Xsd::Conformance::Runner do
  subject(:runner) do
    described_class.new(
      File.expand_path("../../../conformance/cases", __dir__),
    )
  end

  describe "#cases" do
    it "discovers every case directory with a schema" do
      expected = Dir.glob(
        File.expand_path("../../../conformance/cases/*/schema.xsd", __dir__),
      ).length

      expect(runner.cases.length).to eq(expected)
      expect(runner.cases.map(&:name)).to include("particles-sequence")
    end

    it "requires valid and invalid instances for each case" do
      runner.cases.each do |kase|
        expect(kase.valid).not_to be_empty, "#{kase.name} has no valid-*"
        expect(kase.invalid).not_to be_empty, "#{kase.name} has no invalid-*"
      end
    end
  end

  describe "#run" do
    it "measures every case in both modes" do
      results = runner.run

      expect(results.length).to eq(runner.cases.length * 2)
      expect(results.map(&:mode).uniq).to contain_exactly(:engine, :pipeline)
    end

    it "passes the canonical sequence case in both modes" do
      result = runner.run.find do |r|
        r.case_name == "particles-sequence" && r.mode == :engine
      end

      expect(result).not_to be_nil
      expect(result.failures).to be_empty
      expect(result.passed).to eq(result.total)
    end

    it "passes every case in pipeline mode" do
      results = runner.run.select { |r| r.mode == :pipeline }

      failures = results.filter_map do |r|
        next if r.failures.empty?

        "#{r.case_name}: #{r.failures.join(', ')}"
      end

      expect(failures).to be_empty
    end
  end

  describe "#report" do
    it "renders per-mode pass-rates" do
      report = runner.report(runner.run)

      expect(report).to include("engine")
      expect(report).to include("pipeline")
      expect(report).to match(/\d+\.\d%\)/)
    end
  end
end
