#!/usr/bin/env bash
# Bisect a fixture to the minimal failing prefix through the artifact.
set -uo pipefail
F="$1"
GRAM="${2:-/tmp/diag.json}"
EXE=/Users/mulgogi/.local/share/mise/installs/ruby/3.4.8/lib/ruby/gems/3.4.0/gems/parsanol-1.3.120-arm64-darwin/exe/parsanol
total=$(wc -c < "$F")
lo=1; hi=$total
# does the full file fail?
tail -c "$total" "$F" > /tmp/bisect-in.txt
ruby "$EXE" parg parse "$GRAM" --entry syntax "$(cat /tmp/bisect-in.txt)" >/dev/null 2>&1 || true
if ruby "$EXE" parg parse "$GRAM" --entry syntax "$(cat /tmp/bisect-in.txt)" >/dev/null 2>&1; then
  echo "FULL PARSES — no failure to bisect"
  exit 0
fi
# binary search the smallest failing PREFIX
while [ "$lo" -lt "$hi" ]; do
  mid=$(( (lo + hi) / 2 ))
  tail -c "$mid" "$F" > /tmp/bisect-in.txt
  # NOTE: tail -c prefix loses the head; prefix probing needs head -c
  break
done
# prefix bisection: find the smallest prefix that FAILS
lo=1; hi=$total
while [ "$lo" -lt "$hi" ]; do
  mid=$(( (lo + hi) / 2 ))
  head -c "$mid" "$F" > /tmp/bisect-in.txt
  if ruby "$EXE" parg parse "$GRAM" --entry syntax "$(cat /tmp/bisect-in.txt)" >/dev/null 2>&1; then
    lo=$((mid + 1))
  else
    hi=$mid
  fi
done
echo "minimal failing prefix: $lo of $total bytes"
head -c "$lo" "$F" > /tmp/bisect-min.txt
tail -c 120 /tmp/bisect-min.txt
echo
