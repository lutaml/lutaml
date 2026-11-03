---
layout: default
title: Changelog
nav_order: 99
permalink: /CHANGELOG
---

# Changelog

All notable changes to lutaml-xsd will be documented in this file.

## [Unreleased]

## [1.1.3] - 2025-05-15

### Added

- RELAX NG (RNG/RNC) to XSD conversion via `Lutaml::Xsd::RngToXsdConverter`
- Build LXR packages directly from `.rng` and `.rnc` files
- `SchemaRepository.load_from_file` accepts `.rng` and `.rnc` schema files
- Inline/anonymous complex type display in SPA documentation — complex types defined within elements are now surfaced with synthetic names
- Group tree view in SPA — new `GroupTreeItem` component for interactive, nested rendering of groups with choices and sequences
- Sequence and choice serialization in SPA — `xs:sequence` and `xs:choice` model groups are fully serialized with nesting support
- Schema include display in SPA documentation

### Fixed

- SPA generation error when serializing SimpleContent types
- Schema validation error handling

## [1.1.2] - 2025-05-12

- Refactor: eliminate `send()` calls in lutaml-xsd (22 → 0)
- Refactor: eliminate `respond_to?` duck-typing in lutaml-xsd (371 → 1)
- Fix: merge included schemas by namespace, refactor SchemaSerializer for DRY/security

## [1.1.1] - 2025-05-09

- Fix: merge included schemas by namespace, refactor SchemaSerializer for DRY/security

## [1.1.0] - 2025-05-08

- Fix: SVG diagram generation for XSD type definitions

## [0.1.0] - 2024-11-18

- Initial release