require "benchmark"
require "spec_helper"

RSpec.describe Expressir::Express::RemarkAttacher do
  # Remark attachment answers per-remark questions from whole-source scans.
  # Every such scan MUST be built once per source and reused. Rebuilding one
  # per remark is quadratic in (lines x remarks): it is invisible on small
  # fixtures, and on a comment-dense schema it has cost 90x the whole parse.
  #
  # These examples assert the invariant — how many times the shared structure
  # is built — rather than wall-clock time, so they cannot flake on a slow CI
  # runner while still catching the regression exactly.
  describe "shared source scans" do
    let(:source) do
      functions = Array.new(40) do |i|
        <<~EXPRESS
          FUNCTION f#{i}(a : INTEGER) : LOGICAL;
            LOCAL
              t : INTEGER := 0;
            END_LOCAL;
            IF (a > 0) THEN
              t := 1;
              -- trailing comment #{i}
            END_IF;
            RETURN (TRUE);
            -- function tail #{i}
          END_FUNCTION;
        EXPRESS
      end
      "SCHEMA perf_schema;\n#{functions.join("\n")}\nEND_SCHEMA;\n"
    end

    # 80 remarks reach the trailing path; a per-remark rebuild would show up
    # as 80 builds instead of 1.
    it "builds the active scope map once, not once per remark" do
      builds = 0
      # The attacher is constructed inside the builder, so there is no
      # instance to hold; counting calls is the only way to assert the
      # invariant, and the count is the whole point of the example.
      allow_any_instance_of(described_class)
        .to receive(:build_active_scope_map)
        .and_wrap_original do |original, *args|
          builds += 1
          original.call(*args)
        end

      Expressir::Express::Parser.from_exp(source)

      # 80 remarks reach the trailing path; a per-remark rebuild counts 80.
      expect(builds).to eq(1)
    end

    it "keeps attachment cost proportional to the source, not quadratic" do
      small = Expressir::Express::Parser.from_exp(source)
      expect(small).not_to be_nil

      # Four times the source with four times the remarks must not cost
      # sixteen times the work. A generous ceiling keeps this stable on slow
      # runners while still failing on a quadratic rebuild.
      big_body = source.sub("SCHEMA perf_schema;\n", "").sub("END_SCHEMA;\n", "")
      big = "SCHEMA perf_schema;\n#{big_body * 4}END_SCHEMA;\n"

      # Best-of-3 keeps single-run jitter from breaking the bound on loaded
      # CI runners while still failing on a quadratic rebuild (~16x).
      best_time = lambda do |exp|
        Array.new(3) do
          GC.start
          Benchmark.realtime { Expressir::Express::Parser.from_exp(exp) }
        end.min
      end

      small_time = best_time.call(source)
      big_time = best_time.call(big)

      expect(big_time).to be < (small_time * 12)
    end
  end
end
