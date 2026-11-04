#!/usr/bin/env bash
# Delta-debug a failing fixture: remove line-ranges while the remainder
# still fails through the artifact; prints the minimized file.
set -uo pipefail
F="$1"
GRAM="${2:-/tmp/diag.json}"
EXE=/Users/mulgogi/.local/share/mise/installs/ruby/3.4.8/lib/ruby/gems/3.4.0/gems/parsanol-1.3.120-arm64-darwin/exe/parsanol
cp "$F" /tmp/ddmin.cur

fails() {
  ruby "$EXE" parg parse "$GRAM" --entry syntax "$(cat /tmp/ddmin.cur)" >/dev/null 2>&1
}
fails || { echo "input does not fail — nothing to minimize"; exit 1; }

n=$(wc -l < /tmp/ddmin.cur)
chunk=$((n / 4)); [ "$chunk" -lt 1 ] && chunk=1
while [ "$chunk" -ge 1 ]; do
  changed=1
  while [ "$changed" -eq 1 ]; do
    changed=0
    start=1
    while [ "$start" -le "$n" ]; do
      end=$((start + chunk - 1))
      cp /tmp/ddmin.cur /tmp/ddmin.prev
      awk -v s="$start" -v e="$end" 'NR < s || NR > e' /tmp/ddmin.prev > /tmp/ddmin.cur
      if fails; then
        changed=1
        n=$(wc -l < /tmp/ddmin.cur)
      else
        cp /tmp/ddmin.prev /tmp/ddmin.cur
      fi
      start=$((end + 1))
    done
    n=$(wc -l < /tmp/ddmin.cur)
  done
  chunk=$((chunk / 2))
done
echo "=== minimized ($(wc -l < /tmp/ddmin.cur) lines):"
cat /tmp/ddmin.cur
