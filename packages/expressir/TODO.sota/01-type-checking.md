# 01 — Static type checking of expressions

The Checker resolves references (TODO.eengine/02/03); this task gives
it TYPES: full static checking of the expression and statement
language per ISO 10303-11 ch.12/13/8/9.

## Tiers (each ships)

1. Clause map: expression grammar ↔ ISO 10303-11 12.x productions ↔
   eeng check.lisp expression methods, with the typing rule for each
   (operand domains, result type). Table in this file before code.
2. Operator domains: arithmetic on the NUMBER family, logical on
   BOOLEAN/LOGICAL, relational polymorphism, string/binary ops,
   aggregate operators (INDEX/QUERY/SUM and friends).
3. Aggregates: element types through indexing/slicing, bounds vs
   literals where static, nested aggregates.
4. SELECT/ENUM membership: assignment compatibility, IN-of-enum,
   `x : t := expr` compatibility in CONSTANT/LOCAL/DERIVE initializers.
5. Statement flow: assignment compatibility, IF/CASE selector types,
   REPEAT control types, function RETURN type vs return statements.
6. WHERE/UNIQUE structural checks: expression boolean-ness, UNIQUE
   label uniqueness, rule FOR-entity containment for referenced
   attributes.

## Interface

`Checker#check_expression_types(schema)` emitting notes with eeng ids
where check.lisp has them, own ids (`:check_expr_*`) citing clauses
where it does not (mirror TODO.eengine/02's SELF-redeclaration
precedent).

## Acceptance

- Corpus-clean over the 265-file resource slice (foreign-blindness
  rule applies: unresolvable names skipped, not flagged).
- eeng differential for the expression checks eengine actually
  implements; standard wins on divergence.

## Clause map (tier 2 — operator domains)

Model operator vocabulary: `BinaryExpression` constants (ADDITION,
SUBTRACTION, MULTIPLICATION, REAL_DIVISION, INTEGER_DIVISION, MODULO,
EXPONENTIATION, COMBINE, EQUAL, NOT_EQUAL, LESS_THAN,
LESS_THAN_OR_EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, IN, LIKE,
INSTANCE_EQUAL, INSTANCE_NOT_EQUAL, AND, OR, XOR);
`UnaryExpression` (PLUS, MINUS, NOT); `Interval`.

| operator | ISO 10303-11:2004 clause | operand domains | result |
|----------|--------------------------|-----------------|--------|
| unary `+` `-` (PLUS/MINUS) | 12.1 | numeric | numeric |
| `not` (NOT) | 12.4 | logical | logical |
| `+` (ADDITION) | 12.1 add; 12.5.2 string concat; 12.3.2 binary concat; 12.6 union (table 17 admits aggregate+element singletons on either side) | num,num; str,str; bin,bin; agg,agg; agg,elem; elem,agg | num / str / bin / agg |
| `-` (SUBTRACTION) | 12.1; 12.6 difference (table 18: aggregate left, element singleton right) | num,num; agg,agg; agg,elem | num / agg |
| `*` (MULTIPLICATION) | 12.1; 12.6 intersection (both operands aggregates) | num,num; agg,agg | num / agg |
| `/` (REAL_DIVISION) | 12.1 | numeric | real |
| `**` (EXPONENTIATION) | 12.1 | numeric | num (int if both int) |
| `div` `mod` | 12.1 | numeric (reals truncated) | integer |
| `and` `or` `xor` | 12.4 | logical,logical | logical |
| `=` `<>` | 12.2.1 | comparable: numeric, logical, string, binary, enum; aggregates and entities also admitted | logical |
| `<` `<=` `>` `>=` | 12.2.1; 12.6 subset/superset | ordering families only (numeric, logical, string, binary, non-extensible enum); if either side is aggregate, subset/superset semantics (agg,agg) | logical |
| `:=:` `:<>>:` (INSTANCE_EQUAL/NOT_EQUAL) | 12.2.2 | instance types (entity, aggregate) | logical |
| `in` (IN) | 12.2.3 | rhs aggregate; lhs compatible with rhs base | logical |
| `like` (LIKE) | 12.2.5 | string,string | logical |
| `\|\|` (COMBINE) | 12 intro (precedence table note) | complex entity construction (entity operands) | entity |
| interval | 12.2.4 | low/item/high mutually comparable (numeric, string, enum) | logical |

Static type lattice: `:integer :real :number :logical :boolean :string
:binary :enum :aggregate :entity :select :generic :unknown`. Inference:
literals direct; declared types via the schema's types (SimpleReference
→ find_type → underlying_type recursion); references via the enclosing
declaration's environment (constants, parameters, variables, entity
attributes); enum members are AttributeReferences whose base resolves
to an enumeration TYPE; function calls resolve to the function's
return type.

Flagging rule: a domain violation is noted only when BOTH operand
types are known (`:generic` and `:unknown` never flag) — the corpus
never produces false positives.

eengine divergence: kernel/check.lisp's expression check-p11 methods
traverse structurally only — eengine performs NO operator-domain
typing. These checks therefore carry new `:check_expr_operand_domain`
ids citing their clauses; there is no eengine note id to keep.

- Tier 1 clause map: done (above).
- Tier 2 operator domains: done — `Checker#check_expression_types`,
  note id `:check_expr_operand_domain` with the clause in the message;
  spec `spec/expressir/express/checker_expression_types_spec.rb`
  (9 examples); corpus-clean over the 265-file resource slice (255
  scanned, 0 notes) after clause 12.6 table 17's union-with-singleton
  was admitted.
- Tier 3 indexing: done — IndexReference resolves to the aggregate's
  base element (12.6.1/12.3.1/12.5.1); index positions numeric
  (production 236); the difference operator admits an element
  singleton right operand with an aggregate left (12.6 table 18).
- Tier 4 initializer compatibility: done — CONSTANT/DERIVE/LOCAL
  initializers checked against their declared types (12.11): numeric
  widening integer→real→number, logical/boolean family, enum identity
  via declaration resolution, entity specialization via
  supertype_closure, select-accepting slots, aggregate slots. Corpus
  clean (261 schemas, 0 notes).
- Tier 5 statement flow: done — assignment compatibility (13.2.1),
  if conditions logical (13.5), repeat controls (13.6), return
  compatibility + procedure-return restriction (13.7).
- Tier 6 WHERE/UNIQUE structure: done — WHERE expressions logical
  (9.4), duplicate UNIQUE labels (9.4); rule FOR-entity containment
  remains covered by bound_identifiers' deliberate over-approximation.

## Status: done

Engine finding: parsing identical source after many interleaved
check-parse cycles in one process can diverge (attr type arrives as a
SimpleReference instead of the builtin node) — a parsanol parse-cache
issue, worked around in the initializer spec by checking in a fresh
subprocess; separate investigation owed.
