# eengine check-p11 catalog — every note id in `kernel/check.lisp`

Extracted from `~/src/external/exp-engine-engine/kernel/check.lisp`
(`noting-check` sites; 57 `check-p11` methods, 29 distinct note ids).
CI gate: re-extract and diff against this file — a new eeng note must
land here with a coverage decision before its release ships.

| eeng note id | what it flags | expressir status |
|---|---|---|
| check-schema-interface-redundant | redundant same-kind interface | ✅ `check_schema_interface_redundant` |
| check-schema-iface-resource-duplicate | duplicate resources on same-kind interface | ✅ `check_schema_iface_resource_duplicate` |
| check-subtype-ref | SUBTYPE OF references missing entity | ✅ `check_subtype_ref` |
| check-subtype-cycle | inheritance cycle | ✅ `check_subtype_cycle` (path-tracked DFS; eeng has no cycle note — superset) |
| check-duplicate-declaration | duplicate declaration in schema | ✅ superset (eeng delegates to pass-2) |
| check-where-name-pattern | WHERE label not WR<n> | ✅ `check_where_name_pattern` |
| check-unique-name-pattern | UNIQUE label not UR<n> | ✅ `check_unique_name_pattern` |
| check-unresolved-ref | interface resource / reference not found | ✅ `check_unresolved_ref` (aggregate) |
| check-select-extended-type | select extending non-select | ✅ `check_select_extended_type` |
| check-enumeration-extended-type | enum extending non-enum | ✅ `check_enumeration_extended_type` |
| check-self-schema-reference | self-qualified string literals (#125) | ✅ superset of check-string-no-schema |
| check-subtypeof-invalid | SUBTYPE OF target invalid as supertype | 🔜 tranche 1 |
| check-supertype-ref | SUPERTYPE OF expression references invalid entity | 🔜 tranche 1 |
| check-select-named-type | select references a non-named (constructed) type | 🔜 tranche 1 |
| check-constant-type | unparsed/invalid CONSTANT type | ◐ n/a — expressir parses strictly (error, not note) |
| check-local-type | unparsed/invalid LOCAL type | ◐ n/a — same |
| check-agg-type | invalid aggregate bound/type | 🔜 tranche 2 |
| check-parameter-type | invalid parameter type | 🔜 tranche 2 |
| check-attrib-name-fun | attribute name shadows a function | 🔜 tranche 2 |
| check-string-no-entity | string references unknown ENTITY | 🔜 tranche 2 (rides #125 string walk) |
| check-string-no-attribute | string references unknown ATTRIBUTE | 🔜 tranche 2 |
| check-string-reference | generic string reference validity | 🔜 tranche 2 |
| check-fun-return-type | invalid function return type | 🔜 tranche 3 |
| check-inverse-entity | INVERSE target not an entity | ✅ `check_inverse_entity` (tranche 3) |
| check-inverse-derive | INVERSE contradicts DERIVE | ✅ `check_inverse_derive` (tranche 3) |
| check-inverse-inverse | INVERSE ↔ INVERSE conflict | ✅ `check_inverse_inverse` (tranche 3) |
| check-inverse-attrib-ref | INVERSE attribute ref not found | ✅ `check_inverse_attrib_ref` (tranche 3; walks the supertype closure — superset of eeng's own-attributes lookup) |
| check-inverse-agg | INVERSE aggregate misuse | ◐ n/a — the grammar only parses SET/BAG inverse aggregates (parser errors first) |
| qualified-attrib-group-not-found | SELF\Group group not found | ✅ `resolve_group` (tranche 3) |
| qualified-attrib-group-not-ancestor | SELF\Group group not an ancestor | ✅ redeclaration groups only, exactly eeng's `%%inheritance!` scope — TYPEOF-guarded expression views (SELF\subface) are not flagged (tranche 3) |
| qualified-attrib-attr-not-found | SELF\Group.attr attr not found | ✅ expression group qualifiers, own-attributes scope (tranche 3) |
| check-declaration | (wrapper — notes aggregation, not a check) | — n/a |

Tranches:
1. mechanical, model-local — SELECT named-type, SUBTYPE OF/SUPERTYPE
   OF target validity.
2. string-reference family (rides the #125 string walk) + name
   shadowing + aggregate bounds.
3. INVERSE family + SELF\ qualified-attribute resolution (needs the
   reference-resolution depth of ResolveReferencesModelVisitor).
