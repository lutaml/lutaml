# 03 — ItemGraph

## Goal
Cross-schema graph API over a parsed repository: subtype edges, interface
(USE FROM/REFERENCE FROM) edges, transitive queries — feeding suma doc
generation (hyperlink coverage, "used by" sections, dependency diagrams).

## Evidence
SMRL full-set load proved the data: 37.7k subtype edges, 5.5k interface
edges over 1307 schemas (TODO.memory SMRL notes). The class is the
documented remaining gap.

## Shape
- `Expressir::Model::ItemGraph` built from a Repository (or a
  LazyRepository hydrated once)
- `subtypes(id)`, `supertypes(id)`, `used_by(id)`, `uses(id)`,
  `transitive_subtypes(id)` — downcased-id keyed, cycle-safe
- built once per repository; O(V+E)

## Acceptance
- specs over a multi-schema fixture (diamond subtyping, mutual USE FROM)
- SMRL smoke: edge counts match the recorded 37.7k/5.5k within tolerance
