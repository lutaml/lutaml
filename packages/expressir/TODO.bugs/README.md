# TODO.bugs

Track all architectural and code-cleanliness work.

## Status

**All 30 TODOs resolved.** 24 implemented, 4 accepted as design decisions
(14, 16) or deferred with clear reasoning (28, 29).

## Index

| # | Priority | Status | Title |
| --- | --- | --- | --- |
| [01](01-stale-transformer-autoload.md) | P0 | done | Delete stale `Transformer` autoload |
| [02](02-parser-class-instance-vars.md) | P0 | done | Replace class-level mutation in `Parser` |
| [03](03-builder-mutable-state.md) | P1 | done | Thread `BuilderContext` |
| [04](04-formatter-public-send-dispatch.md) | P1 | done | Registration-time guard |
| [05](05-anonymous-formatter-subclass.md) | P1 | done | Cache named formatter classes |
| [06](06-collection-registry-single-source.md) | P1 | done | Consolidate `SCOPE_DECL_COLLECTIONS` |
| [07](07-require-relative-cleanup.md) | P2 | done | Replace `require_relative` with autoload |
| [08](08-require-expressir-in-commands.md) | P2 | done | Remove `require "expressir/..."` |
| [09](09-parser-split.md) | P2 | done | Split parser.rb into grammar + scanner + facade |
| [10](10-to-s-override.md) | P2 | done | Rename `to_s` to `format` |
| [11](11-parser-class-variables.md) | P3 | done | Replace `@@` class variables |
| [12](12-marker-modules-vs-registry.md) | P3 | done | `collection_attributes` macro |
| [13](13-string-literal-scanner-limitation.md) | P1 | done | `:in_string` scanner state |
| [14](14-model-formatting-leak.md) | P1 | accepted | Model formatting — domain coupling |
| [15](15-expression-children-macro.md) | P1 | done | `child_attributes` macro |
| [16](16-pretty-formatter-duplication.md) | P1 | accepted | PrettyFormatter — intentional specialization |
| [17](17-snake-case-cache-mutable-constant.md) | P1 | done | Thread-local snake_case cache |
| [18](18-const-get-private-constants.md) | P2 | done | Remove `private_constant` |
| [19](19-format-methods-public.md) | P2 | done | `send` dispatch for private methods |
| [20](20-coverage-nested-entities-dedup.md) | P2 | done | Coverage uses `collection_attributes_list` |
| [21](21-operator-tokens-secondary-dispatch.md) | P2 | done | Remove OPERATOR_TOKENS set |
| [22](22-builder-fast-path-wrappers.md) | P2 | done | Remove fast-path wrappers |
| [23](23-coverage-inverse-maps.md) | P2 | done | Derive maps from `TYPE_PAIRS` |
| [24](24-streaming-builder-complexity.md) | P3 | done | Split `convert_ast_format` |
| [25](25-debug-puts-in-production.md) | P3 | done | Remove debug puts |
| [26](26-generic-entity-children-misplaced.md) | P0 | done | Fix misplaced `children` method |
| [27](27-package-build-god-method.md) | P1 | done | Split `Package#build` |
| [28](28-package-god-class.md) | P2 | deferred | Package 1266-line god class |
| [29](29-validate-ascii-god-class.md) | P2 | deferred | ValidateAscii god class |
| [30](30-unicode-map-extraction.md) | P2 | done | Extract unicode map to constant |
