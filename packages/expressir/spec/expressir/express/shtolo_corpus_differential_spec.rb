# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

# Filesystem-aware helpers for the corpus differential below, kept
# module-level so they can be tested directly.
module ShtoloCorpusDifferential
  module_function

  # Resolve a bare `eengine` through PATH. File.executable? alone only
  # sees the current directory (#454), which made the differential skip
  # on machines with eengine installed and on PATH.
  def eengine_on_path
    names = ["eengine"]
    # Windows executability is extension-driven, so an eengine.exe on
    # PATH is invisible to a bare-name probe (#487 follow-up).
    names.concat(ENV.fetch("PATHEXT", ".exe;.bat;.cmd").split(";")) if Gem.win_platform?
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
      .flat_map { |dir| names.map { |name| File.join(dir, name) } }
      .find { |candidate| File.executable?(candidate) }
  end

  # Removes `--` comments from formatted EXPRESS, leading or trailing,
  # without touching string literals. eengine's concatenation separators
  # sit at the end of the PRECEDING declaration's last line (#454), so a
  # line-anchored strip misses them — while a blind `--[^\n]*` strip
  # would cut a `--` inside a string literal.
  def strip_express_comments(text)
    text.each_line.map { |line| strip_line_comments(line) }.join
  end

  def strip_line_comments(line)
    out = +""
    in_string = false
    i = 0
    while i < line.length
      ch = line[i]
      if in_string
        out << ch
        if ch == "'"
          if line[i + 1] == "'"
            out << "'"
            i += 1
          else
            in_string = false
          end
        end
      elsif ch == "'"
        in_string = true
        out << ch
      elsif ch == "-" && line[i + 1] == "-"
        break
      else
        out << ch
      end
      i += 1
    end
    out = out.sub(/[ \t]+\z/, "")
    out << "\n" if line.end_with?("\n") && !out.end_with?("\n")
    out
  end
end

# Corpus differential for the SHTOLO flattener (TODO.parity-ee/14):
# for every module ARM in the STEPmod checkout, flatten it OUR way and
# compare against eengine's own concatenated reference. The primary
# gate is parser-level AND body-level: we read eengine's reference
# file with our parser and diff every declaration's formatted text —
# names, kinds, and bodies. eengine's --concat_compare verdict is a
# second signal where its report printer survives.
#
# ORACLE_CRASH IS NOT PARITY: eengine's report printer dies with an
# unbound INTERFACE-ADD-VALUE slot whenever the compare finds an
# interface-level difference it cannot print — and the artifact-stage
# trial deliberately has no interfaces, so eeng almost always finds
# one. Crashed modules are classified :unverified (eengine confirmed
# nothing) and reported in the failure message; the body-level diff
# is what actually gates. The printer bug exists in 5.0.20-Beta1,
# 5.1.0, and 5.2.8 alike. MIM concatenates exceed the oracle's pass-2
# parser, so the corpus is the ARM set.
#
# Interfaces are excluded from the body diff BY DESIGN: the artifact
# stage produces one merged schema with the interface closure already
# dissolved into it, while eeng's concatenation keeps interface
# clauses per schema.
#
# Runs only when the oracle exists and SHTOLO_CORPUS is set; module
# count bounded by SHTOLO_CORPUS_LIMIT (default 10).
RSpec.describe Expressir::Express::Shtolo, :production_scale do
  include ShtoloCorpusDifferential

  let(:eeng) do
    [ENV.fetch("EENG_BIN", nil),
     # `rake oracle:fetch` caches the pinned expresslang release here
     File.expand_path("../../../tmp/oracle/eengine", __dir__),
     File.expand_path("~/src/external/exp-engine-engine/eengine-5.0.20-Beta1-mac00sbcl",
                      __dir__)]
      .compact.find { |candidate| File.executable?(candidate) } ||
      ShtoloCorpusDifferential.eengine_on_path
  end

  let(:stepmod) do
    ENV.fetch("STEPMOD_ROOT", nil) || File.expand_path("~/src/mn/iso-10303", __dir__)
  end

  let(:limit) { Integer(ENV.fetch("SHTOLO_CORPUS_LIMIT", "10"), 10) }

  def modules_list
    list = Expressir.root_path.join("spec/fixtures/eeng/modules.lst")
    File.exist?(list) ? File.readlines(list).map(&:strip).reject(&:empty?) : []
  end

  def kinds
    %i[types entities functions procedures rules constants]
  end

  before do
    # An explicitly pointed-at oracle that is missing is a config
    # error, not a reason to skip silently (#454).
    if (bin = ENV.fetch("EENG_BIN", nil)) && !File.executable?(bin)
      raise "EENG_BIN=#{bin} is not an executable"
    end

    unless eeng
      skip "oracle binary not present (run bundle exec rake oracle:fetch, " \
           "set EENG_BIN, or put eengine on PATH)"
    end
    skip "STEPmod checkout not present at #{stepmod} (set STEPMOD_ROOT)" unless File.directory?(stepmod)
    skip "set SHTOLO_CORPUS=1 to run" unless ENV["SHTOLO_CORPUS"]
  end

  it "carries the same declarations and bodies as eengine's reference" do
    verdicts = Hash.new(0)
    failures = []

    modules_list.first(limit).each do |name|
      arm = File.join(stepmod, "schemas/modules/#{name}/arm.exp")
      if File.exist?(arm)
        verdict = compare_module(arm)
        verdicts[verdict] += 1
        ok = %i[same unverified]
        failures << "#{name}(#{verdict})" unless ok.include?(verdict)
      else
        verdicts[:missing] += 1
      end
    end

    expect(failures).to be_empty,
                        "verdicts #{verdicts.inspect}; failing modules: #{failures.join(', ')}"
  end

  # :same          bodies match AND eengine agrees
  # :unverified    our body-level diff is clean but eengine's compare
  #                crashed before rendering its verdict (its printer
  #                bug) — reported, never treated as pass evidence
  # :different     declarations or bodies disagree — a real parity gap
  # :concat_error / :flatten_error  pipeline failures
  def compare_module(arm)
    Dir.mktmpdir("shtolo-corpus") do |dir|
      reference = concat_reference(arm, dir)
      return :concat_error unless reference

      trial = flatten_trial(arm, dir)
      return :flatten_error unless trial

      return :different unless declaration_bodies_equal?(trial, reference)

      out = run_eeng("--concat_compare", "-mode", "arm_concatenated",
                     "-trial_schema", trial, "-reference_schema", reference)
      return :unverified if out.nil? || out.include?(";; Error")

      out.include?("** No differences detected **") ? :same : :different
    end
  end

  def concat_reference(arm, dir)
    run_eeng("--concat_schema", "-mode", "arm_shortform",
             "-schema", arm, "-stepmod", stepmod, "-out-dir", dir)
    Dir[File.join(dir, "*_concatenated.exp")].first
  end

  def flatten_trial(arm, dir)
    files = Expressir::Commands::ParityInputs
      .closure_paths(arm, stepmod: stepmod).select { |f| File.exist?(f) }
    repo = Expressir::Express::Parser.from_files(files)
    name = "#{File.basename(File.dirname(arm)).downcase}_arm"
    root = repo.schemas.find { |s| s.id.safe_downcase == name }
    return nil unless root

    opts = { extenders: :none, prune: false, stage: :artifact }
    schema = described_class.new(root, repo, **opts).flatten.schema
    trial = File.join(dir, "#{name}_trial.exp")
    File.write(trial, Expressir::Express::Formatter.format(schema))
    trial
  end

  # {kind => {downcased name => formatted body}} across all schemas.
  # A name-only diff cannot see changed WHERE rules or attribute
  # types; bodies can. Bodies compare CASE-INSENSITIVELY (eengine's
  # writers lowercase identifiers) and with comments stripped: both
  # eengine's `-- <schema> (path)` separators and our remark overlay
  # are annotation, not declaration content.
  def declaration_bodies(path)
    repo = Expressir::Express::Parser.from_files([path])
    bodies = Hash.new { |h, k| h[k] = {} }
    repo.schemas.each do |schema|
      kinds.each do |kind|
        Array(schema.public_send(kind)).each do |decl|
          next unless decl.respond_to?(:id) && decl.id

          body = Expressir::Express::Formatter.format(decl)
          bodies[kind][decl.id.safe_downcase] =
            strip_express_comments(body).downcase
        end
      end
    end
    bodies
  end

  def declaration_bodies_equal?(trial, reference)
    declaration_bodies(trial) == declaration_bodies(reference)
  end

  def run_eeng(*args)
    out, _err, _status = Open3.capture3(eeng, *args)
    out
  rescue StandardError
    nil
  end
end
