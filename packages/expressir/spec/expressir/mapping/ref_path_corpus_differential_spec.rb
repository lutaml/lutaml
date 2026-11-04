# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Corpus differential for the MIM reference-path validator (#88): load
# every module's mapping.yaml from a STEPmod checkout, parse each
# reference path, and validate it against that module's ARM/MIM
# interface closure. Unlike the unit specs (synthetic schemas), this
# exercises the full corpus notation against real schemas and reports
# exactly which module/attribute/step fails.
#
# Opt-in: REFPATH_CORPUS=1 with the checkout at STEPMOD_ROOT (default
# ~/src/mn/iso-10303). Module count bounded by REFPATH_CORPUS_LIMIT.
# Genuine drift already found in the corpus (mapping references a
# type no shipped schema declares). New entries only via a finding.
KNOWN_DRIFT_MODULES = [
  "annotated_3d_model_equivalence_inspection_result",
].freeze

RSpec.describe Expressir::Mapping::RefPath, :production_scale do
  let(:stepmod) do
    ENV.fetch("STEPMOD_ROOT", nil) || File.expand_path("~/src/mn/iso-10303", __dir__)
  end

  let(:limit) { Integer(ENV.fetch("REFPATH_CORPUS_LIMIT", "20"), 10) }

  before do
    skip "STEPmod checkout not present at #{stepmod} (set STEPMOD_ROOT)" unless File.directory?(stepmod)
    skip "set REFPATH_CORPUS=1 to run" unless ENV["REFPATH_CORPUS"]
  end

  it "validates every reference path in the module corpus" do
    modules = Dir.children(File.join(stepmod, "schemas/modules")).sort
      .select { |m| File.exist?(File.join(stepmod, "schemas/modules/#{m}/mapping.yaml")) }
      .first(limit)

    failures = []
    parse_errors = []
    path_count = 0

    modules.each do |name|
      dir = File.join(stepmod, "schemas/modules/#{name}")
      repo = build_repo(dir)
      next unless repo

      document = Expressir::Mapping.load_file(File.join(dir, "mapping.yaml"))
      Expressir::Mapping.refpaths(document).each do |location, content|
        path_count += 1
        parsed = described_class.parse(content)
        parsed.parse_errors.each do |error|
          parse_errors << "#{name} #{location}: #{error}"
        end
        described_class.validate(parsed, repo).each do |issue|
          next if KNOWN_DRIFT_MODULES.include?(name)

          failures << "#{name} #{location} [step #{issue.step}]: #{issue.message}"
        end
      end
    end

    expect(path_count).to be > 0
    expect(parse_errors).to be_empty,
                            "parse errors in #{parse_errors.size} paths; " \
                            "first: #{parse_errors.first}"
    expect(failures).to be_empty,
                        "#{failures.size} refpath issues; first: " \
                        "#{failures.first(5).join(' | ')}"
  end

  def build_repo(dir)
    files = [File.join(dir, "arm.exp"), File.join(dir, "mim.exp")]
      .compact.select { |f| File.exist?(f) }
      .flat_map { |root| Expressir::Commands::ParityInputs.closure_paths(root) }
      .uniq.select { |f| File.exist?(f) }
    return nil if files.empty?

    Expressir::Express::Parser.from_files(files)
  rescue StandardError
    # modules with unresolvable closures (missing third-party deps)
    # are out of scope for this differential
    nil
  end
end
