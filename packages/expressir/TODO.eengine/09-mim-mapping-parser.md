# 09 — MIM mapping parser

TODO.parity-ee 18 (expressir#88). Parse + validate MIM reference
paths into a typed model: entity chains `A -> B -> C`, qualifiers
`[attr => val]`, `=>` derived references, `->>` subtype traversal,
`<>` select member. Sources: this checkout's
`schemas/modules/*/mapping.yaml` (`<<express:SCHEMA.ITEM,ITEM>>` link
markup), upstream module.xml `reference_path` bodies, the Part 1x
mapping-annex grammar; the module corpus is the oracle.

## Status: done

- `Expressir::Mapping::RefPath` parses and validates MIM reference
  paths against real schemas (ELF 5006 §§5/8, including the §5
  supertype/tree markers), with corpus differential specs; instance
  level walking shipped in TODO.instance/04.
