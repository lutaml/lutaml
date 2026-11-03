# TODO.max-perf/13 — Unit specs for the key-conversion memoization

## Context

PR #355 optimized `Builder.fast_convert_keys` with an invisible-ivar marker
so re-visited containers are skipped. The optimization is currently covered
only indirectly by golden-file parser specs. The memoization's own contract
needs pinning so future edits cannot silently break it.

## Work

- [x] Unit specs for the converter (renamed `AstKeyConverter.convert`):
      - converts CamelCase keys at every depth; untouched data keeps object
        identity
      - idempotence: converted results convert to themselves
      - marked containers are skipped on re-visits (marker on both paths)
      - frozen input hashes do not raise
- [x] Marker invisibility: marked hashes remain == to unmarked copies and
      survive Marshal round-trip without affecting content

- [x] All contract specs written against the extracted public Expressir::Express::AstKeyConverter (key conversion was promoted from a private Builder helper to its own class — MECE: converting AST keys is not building models)
- [x] Depth conversion, identity preservation, idempotence, marker set on both paths, frozen-hash safety, marker invisibility (== and Marshal), snake_case behavior — spec/expressir/express/ast_key_converter_spec.rb

## Acceptance

Dedicated spec file green; the optimization's behavior is pinned.

## Outcome (from the 2026-09-18 close-out, commit 17aa264)

- [x] Unit specs for the converter (renamed `AstKeyConverter.convert`):
- [x] Marker invisibility: marked hashes remain == to unmarked copies and
- [x] All contract specs written against the extracted public Expressir::Express::AstKeyConverter (key conversion was promoted from a private Builder helper to its own class — MECE: converting AST keys is not building models)
- [x] Depth conversion, identity preservation, idempotence, marker set on both paths, frozen-hash safety, marker invisibility (== and Marshal), snake_case behavior — spec/expressir/express/ast_key_converter_spec.rb

## Status: done

- spec/expressir/express/ast_key_converter_spec.rb pins the extracted AstKeyConverter contract on main.
