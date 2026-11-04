# 16 — PrettyFormatter duplicates declaration formatting from DeclarationsFormatter

**Priority:** P1 (DRY violation)
**Status:** ACCEPTED — duplication is intentional specialization

## Problem

`PrettyFormatter` redefines 5 `format_declarations_*` methods with
indentation and provenance-header differences from the base
`DeclarationsFormatter`.

## Decision

The duplication is **accepted** as intentional specialization.
PrettyFormatter adds provenance headers (`format_provenance_header`),
scope-body helpers (`format_scope_body`, `format_scope_footer`), and
different indentation handling that the base formatter does not need.

A full unification would require parameterizing the base formatter with
indent-width, provenance support, and scope-body rendering — adding
complexity to the common path to serve a specialized variant. The
deletion test fails: removing PrettyFormatter's overrides would
concentrate complexity into the base formatter, making the common path
harder to reason about.

The duplication is bounded (5 methods, ~100 lines) and the two
formatters evolve independently (PrettyFormatter adds features the
base does not need).
