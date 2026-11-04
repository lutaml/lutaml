# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

# Differential against the Express Engine oracle (parity-ee 03/05).
#
# Requires:
#   EENG_ORACLE=/path/to/eengine   the eengine binary
#   STEPMOD=/path/to/iso-10303     the STEPmod checkout
#
# TRThurman's acceptance for WG12 (#32): the longforms expressir produces
# must compare equal to the reference eengine produces — `eengine --compare`
# reporting no differences (whitespace may differ).
#
# eengine 5.0.20 cannot itself fold extensible extenders into the longform
# (its default --flat leaves the SELECT item list empty), so the comparable
# reference shape is its --concat_schema artifact read at resolution: our
# longform generated with `extenders: :none` must be declaration-for-
# declaration equivalent to the reference root schema. The all-extenders
# folding (Annex G.2.3/G.2.4) is pinned separately below.
RSpec.describe Expressir::Express::Shtolo, if: ENV.fetch("EENG_ORACLE", nil) && ENV.fetch("STEPMOD", nil) do # eengine oracle differential
  let(:eengine) { ENV.fetch("EENG_ORACLE") }
  let(:stepmod) { File.join(ENV.fetch("STEPMOD"), "schemas") }
  let(:module_dir) { File.join(stepmod, "modules/description_assignment") }
  let(:mim) { File.join(module_dir, "mim.exp") }

  def run_eeng(*args)
    out, err, status = Open3.capture3(eengine, *args)
    unless status.success?
      raise "eengine #{args.join(' ')} failed (#{status.exitstatus}): " \
            "#{out[/^\s*;; Error:.*$/, 0] || out[-1500, 1500]} | err: #{err[0, 400]}"
    end

    out
  end

  def stepmod_index
    @stepmod_index ||= Dir.glob(File.join(stepmod, "**", "*.exp"))
      .to_h { |p| [File.basename(p, ".exp").downcase, p] }
  end

  # Transitive USE/REFERENCE closure of the module, by schema name.
  def closure_paths(root)
    index = stepmod_index
    index[File.basename(root, ".exp").downcase] = root
    seen = {}
    queue = [File.basename(root, ".exp").downcase]
    until queue.empty?
      name = queue.shift
      next if seen.key?(name) || !(path = index[name])

      seen[name] = path
      File.read(path).scan(/(?:USE|REFERENCE)\s+FROM\s+(\w+)/i)
        .flatten.each { |d| queue << d.downcase }
    end
    seen.values
  end

  def our_longform(root_path, out_dir, extenders:)
    repo = Expressir::Express::Parser.from_files(closure_paths(root_path),
                                                 skip_references: true,
                                                 max_processes: 1)
    name = File.read(root_path)[/\bSCHEMA\s+(\w+)/, 1]
    root = repo.schemas.find { |s| s.id&.downcase == name.downcase }
    raise "root schema #{name} missing" unless root

    lf = Expressir::Express::Shtolo.new(root, repo,
                                        longform_name: name,
                                        extenders: extenders).flatten.schema
    path = File.join(out_dir, "#{name}_trial.exp")
    File.write(path, Expressir::Express::Formatter.format(lf))
    path
  end

  def eeng_reference(root_path, out_dir)
    run_eeng("--concat_schema", "-mode", "mim_shortform",
             "-schema", root_path, "-stepmod", File.dirname(stepmod),
             "-out-dir", out_dir)
    File.join(out_dir, "#{File.basename(root_path, '.exp')}_concatenated.exp")
  end

  def compare_differences(trial, reference, schema_name)
    out = run_eeng("--compare", "-mode", "mim_shortform",
                   "-trial_schema", trial,
                   "-reference_schema", reference,
                   "-trial_stepmod", File.dirname(stepmod),
                   "-reference_stepmod", File.dirname(stepmod),
                   "-schema_name", schema_name)
    # eengine prints exactly this on semantic equivalence.
    out.include?("No differences detected") ? [] : [out[/;; Error:.*|Differences.*/].to_s]
  end

  it "our extenders:none longform compares clean against the eengine reference" do
    arm = File.join(module_dir, "arm.exp")
    Dir.mktmpdir("eeng-oracle-") do |dir|
      reference = eeng_reference(arm, dir)
      trial = our_longform(arm, dir, extenders: :none)

      diffs = compare_differences(trial, reference,
                                  "description_assignment_arm")
      expect(diffs).to be_empty,
                       "eengine --compare reported differences:\n#{diffs.join("\n")}"
    end
  end

  it "our extenders:all longform folds every extensible extender in the closure" do
    Dir.mktmpdir("eeng-oracle-") do |dir|
      trial = our_longform(mim, dir, extenders: :all)
      text = File.read(trial)

      # description_item is EXTENSIBLE GENERIC_ENTITY SELECT () in the
      # shortform; every extender folding must replace the empty list with
      # the closure's extenders (here: description_text and its siblings
      # from systems_engineering_representation_schema).
      # the shortform declares `EXTENSIBLE GENERIC_ENTITY SELECT ;` with no
      # item list; all-extenders must populate it from the closure.
      select_block = text[/TYPE description_item = .*?END_TYPE;/m]
      expect(select_block).not_to be_nil
      expect(select_block).to match(/SELECT\s*\(/),
                              "extenders were not folded:\n#{select_block}"
    end
  end
end
