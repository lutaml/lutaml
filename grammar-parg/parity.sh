#!/usr/bin/env bash
# Corpus parity (issue #578 STEP 1 gate): every .exp fixture must parse
# identically through the DSL and the edition-2 artifact.
# PARITY_LIB: a parsanol checkout whose lib/ carries the compiler fix —
#   PARITY_LIB=~/src/lutaml/parsanol-capfix/lib ./parity.sh
set -uo pipefail
cd "$(dirname "$0")"
EXE=/Users/mulgogi/.local/share/mise/installs/ruby/3.4.8/lib/ruby/gems/3.4.0/gems/parsanol-1.3.121-arm64-darwin/exe/parsanol
LIB="${PARITY_LIB:-}"

# Oversized fixtures bypass the CLI argv limit: parse through the
# artifact API directly, in-process.
big_parity() {
  ruby ${LIB:+-I "$LIB"} -e '
    require "parsanol"
    require "json"
    artifact = Parsanol::PARG::Artifact.from_json(File.read("/tmp/serialized.json"))
    begin
      artifact.parse("syntax", File.read(ARGV[0]), mode: :ruby)
      exit 0
    rescue StandardError
      exit 1
    end' "$1" > /dev/null 2>&1
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
  if ruby "$EXE" parg parse /tmp/serialized.json --entry syntax "$src" \
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
