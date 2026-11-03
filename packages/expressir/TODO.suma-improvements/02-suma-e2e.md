# 02 — Suma full-document E2E on the current stack

## Goal
One clean E2E run of an actual suma document build with expressir 2.4.24 +
metanorma-plugin-lutaml 0.7.53 + current metanorma gems, rendering a real
ISO 10303 module document to XML.

## Why now
The earlier full-render was blocked by the metanorma-document/relaton
0.2.x skew; that ecosystem has moved (metanorma-document 0.5.1, relaton
3.0 pre-alpha). The expressir side is proven current.

## Steps
- locate the suma build entry (~/src/mn/iso-10303 suma config or the
  metanorma-iso document that renders schema pages)
- bundle with current metanorma; render one module doc end to end
- capture XML diffs vs the last good render; if the relaton skew
  persists, name the exact unresolved constraint

## Acceptance
- a rendered module document, or a one-line statement of the precise
  upstream blocker with the failing constraint

## Result: DONE (2026-09-27)

The upstream blocker has cleared. On the iso-10303 ladder (user's
Gemfile WIP + suma from path + relaton prereleases with the rubyzip-3
fix now on rubygems — the fix/rubyzip-3 git pins were dropped as
obsolete):

    bundle exec suma build srl-smol.yml   # one-part SMOL collection
    # => Compiling schema collection... Compiling complete collection...
    # => SMOL-EXIT=0

Artifacts: 286 files in _site/ — real ISO document XML (flavor iso,
schema content present), schema-doc pages, presentation XML. The stale
sums pin was the rubygems suma 0.1.11 (expressir ~> 2.1, metanorma-cli
0.0.3 → broken 2019 stack); suma from source (metanorma ~> 2.3 line)
resolves cleanly.
