# 14 — Model layer embeds EXPRESS formatting logic

**Priority:** P1 (leaky seam)
**Status:** ACCEPTED — design decision documented below

## Problem

`ModelElement#source`, `Schema#source`, `Schema#formatted`, `Schema#full_source`
all call express-layer formatters, creating a dependency from model → express.

## Decision

This coupling is **accepted** as a domain-level design decision. The model
IS the EXPRESS model — it is not a generic data layer that could exist
without the EXPRESS-specific formatting. The `source`/`formatted`/`full_source`
methods are domain behavior of an EXPRESS model element, not generic
serialization.

Attempting to uncouple would:
1. Break dozens of callers (`schema.source`, `schema.formatted` are used
   throughout commands, specs, and coverage code).
2. Add indirection (a presenter/decorator layer) for no real benefit —
   the model and express layers are always loaded together.
3. Diverge from the "rich model" pattern where domain objects carry their
   own domain-specific behavior.

The `@source ||=` caching pattern on Schema already provides lazy
computation: the stored source (from the parser) is returned if available;
otherwise the formatter computes it on first access. This is efficient and
semantically correct.
