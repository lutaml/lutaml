#!/usr/bin/env bash
# Corpus parity (issue #578 STEP 1 gate): every .exp fixture must parse
# identically through the DSL and the edition-2 artifact.
# PARITY_LIB: a parsanol checkout whose lib/ carries unreleased fixes —
#   PARITY_LIB=~/src/lutaml/parsanol-noedition1/lib ./parity.sh
# (applies to the CLI artifact lane too, not just the in-process one)
set -uo pipefail
cd "$(dirname "$0")"
EXE="${PARSANOL_EXE:-$(bundle exec which parsanol)}"
ARTIFACT="$(pwd)/express-grammar.artifact.json"
LIB="${PARITY_LIB:-}"

# Oversized fixtures bypass the CLI argv limit: parse through the
# artifact API directly, in-process.
big_parity() {
  ruby ${LIB:+-I "$LIB"} -e '
    require "parsanol"
    # The split artifact replays its source; the component sources must
    # sit beside it (imports_dir), exactly as the gem lane passes them.
    artifact = Parsanol::PARG::Artifact.from_json(
      File.read(ARGV[1]), imports_dir: File.dirname(ARGV[1]))
    begin
      artifact.parse("syntax", File.read(ARGV[0]), mode: :ruby)
      exit 0
    rescue StandardError
      exit 1
    end' "$1" "$ARTIFACT" > /dev/null 2>&1
}

pass=0; fail=0; skipped=0
for f in $(find /Users/mulgogi/src/lutaml/expressir/spec -name "*.exp" | sort); do
  if [ "$(wc -c < "$f")" -gt 200000 ]; then
    if big_parity "$f"; then art=ok; else art=fail; fi
    if bundle exec ruby -e '
      require "bundler/setup"
      require "expressir"
      begin
        Expressir::Express::Parser.from_exp(File.read(ARGV[0]))
        exit 0
      rescue StandardError, NotImplementedError
        exit 1
      end' "$f" > /dev/null 2>&1; then dsl=ok; else dsl=fail; fi
    if [ "$art" = "$dsl" ]; then pass=$((pass+1)); else
      fail=$((fail+1)); echo "PARITY GAP (big): $f  dsl=$dsl artifact=$art"
    fi
    continue
  fi
  src="$(cat "$f")"
  # artifact accept?
  if ruby ${LIB:+-I "$LIB"} "$EXE" parg parse "$ARTIFACT" --entry syntax "$src" \
      > /tmp/par-artifact.log 2>&1; then art=ok; else art=fail; fi
  # DSL accept?
  if bundle exec ruby -e '
    require "bundler/setup"
    require "expressir"
    begin
      Expressir::Express::Parser.from_exp(File.read(ARGV[0]))
      exit 0
    rescue StandardError, NotImplementedError
      exit 1
    end' "$f" > /dev/null 2>&1; then dsl=ok; else dsl=fail; fi

  if [ "$art" = "$dsl" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "PARITY GAP: $f  dsl=$dsl artifact=$art"
  fi
done
echo "parity: $pass agree, $fail gaps, $skipped skipped"
