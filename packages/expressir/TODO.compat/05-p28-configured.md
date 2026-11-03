# 05-p28-configured — P28 configured binding (ISO 10303-28 clauses 8/10) — the TODO.p28/05 promotion

 configuration directives over the default binding. Acceptance: the TODO.p28/01-04 corpus validates through a configured derivation; clause-cited rules.

## Status: done

- `Expressir::P28::Configuration`
  (`lib/expressir/p28/configuration.rb`): parses the clause 8
  configuration document (annex D `configuration.xsd` shape,
  namespace `urn:iso10303-28:ex`) — options, type/entity/attribute
  directives, nested scopes.
- Applied over the clause 7 default derivation
  (`P28::Xsd.format(schema, configuration:)`): the configuration-
  chosen target namespace (7.7.2 via clause 8), the naming
  convention (7.1.2 via clause 8: initial-upper default,
  camel-case, preserve-case), and explicit type/entity/attribute
  renames — followed through every type reference.
- Default invariant (acceptance): a configuration with no directives
  derives byte-identically to the unconfigured default binding, so
  the TODO.p28/01-04 corpus validates through the configured
  derivation unchanged. Pinned in
  `spec/expressir/p28/configuration_spec.rb` together with the
  rename/naming/namespace rules and the unknown-convention rejection.
- Directives outside the applied subset are registered as divergence
  D-04 in `docs/_guides/compat/interchange.adoc` (clause-cited) and
  pinned by the same spec.
