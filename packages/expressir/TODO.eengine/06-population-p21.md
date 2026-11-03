# 06 — Population / Part 21

TODO.parity-ee 13, scope ladder (each step ships):

1. P21 reader: parsanol grammar for ISO 10303-21 (HEADER entities,
   DATA section: complex instances `(A(...)B(...))`, simple
   `#1=TYPE(...)`, list/set/typed-ref values, enums `.T.`, binary
   `"...`, redefines `/`); a `Model::Population` (header + instances).
2. Population validation against a loaded schema: instance entity
   exists (direct or complex against the supertype graph), attribute
   names/arity match, value types check.
3. eengine differential on the Part 21 fixtures
   (`~/src/mn/iso-10303-detached-docs/sources/iso-10303-21*`).

## Status: done

1. Reader — `Expressir::P21` (parsanol grammar + PopulationBuilder):
   HEADER FILE_* entities, DATA simple/complex instances, lists,
   typed parameters, references, enumerations, binaries, strings
   (doubled-quote escape), `$`/`*`, `/* */` comments.
2. Validator — `Expressir::P21::Validator`: FILE_SCHEMA name,
   instance keywords, complex-record supertype cliques, mapped
   attribute arity in Part 21 order (supertype attributes first;
   DERIVE-redeclared slots keep their position valued `*` per clause
   12.2.6), enumeration membership, instance references,
   typed-parameter resolution; optional short_names map for clause
   12.3 short names.
3. Corpus — ISO 10303-21 Annex H complete exchange structure parses
   and validates clean (13 instances, comments, short names).

eengine differential (ladder step 3) is blocked by the oracle build:
eengine 5.1.0 --validate/--xref abort loading a bare p11 schema
(*PARSE-MODE* NIL) and every -MODE demands a stepmod context, while
--validate itself is flagged "not fully supported" upstream.
