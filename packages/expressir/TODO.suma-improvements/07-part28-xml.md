# 07 — Part 28 XML: select mapping v2 (#276) — DONE

Shipped: the ISO 10303-28 SELECT mapping lives in
lib/expressir/express/xsd.rb (complexType + xs:choice, entity members
as global-element refs, defined-type members by name+type, extensible-
empty fallback to sequence) and is covered by spec/expressir/express/
xsd_spec.rb. The CLI exposes both halves: `expressir xsd` and
`expressir xml-index` (#503).

Remaining escalation (moved to parity-ee 17 scope): validating the
generated XSDs against the Part 28 reference corpus — the detached
docs carry the standard text only, not the reference XSDs.
