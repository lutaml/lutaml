# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Lutaml::Xsd is a Ruby gem for parsing and building XML Schema Definition (XSD) files. It parses XSD content into Ruby objects and can serialize those objects back to XML.

## Commands

```bash
bundle install      # Install dependencies
rake                # Run tests and linting (default task)
rake spec           # Run tests only
rake rubocop        # Run linter only
bundle exec rspec spec/lutaml/xsd_spec.rb  # Run specific test file
bundle exec rspec spec/lutaml/liquid_spec.rb  # Run liquid methods tests
```

## Architecture

### Entry Point
`lib/lutaml/xsd.rb` loads the stack. The public parse entry (provided by
lutaml-model's `Lutaml::Xml::Schema::Xsd`) is
`Lutaml::Xml::Schema::Xsd.parse(xsd, location:)`, returning a `Schema`.
Model extensions live in `lib/lutaml/xsd/xsd_model_extensions.rb`.

### Base Class
`lib/lutaml/xsd/base.rb` - `Lutaml::Xsd::Base` extends `Lutaml::Model::Serializable`. All XSD element classes inherit from it. Provides:
- `to_xml` - Serialize to XML
- `to_formatted_xml` - Pretty-printed XML
- `resolved_element_order` - Elements in original XSD order

### Schema Class
`lib/lutaml/xsd/schema.rb` - Root class representing an XSD schema. Contains collections of all top-level elements (element, complex_type, simple_type, group, attribute, etc.) and handles import/include resolution.

### XSD Element Classes
Each XSD element type has its own class in `lib/lutaml/xsd/`:
- `element.rb`, `attribute.rb`, `complex_type.rb`, `simple_type.rb`
- `group.rb`, `sequence.rb`, `choice.rb`, `all.rb`
- `restriction_simple_type.rb`, `extension_simple_content.rb`, `extension_complex_content.rb`
- `attribute_group.rb`, `import.rb`, `include.rb`, `redefine.rb`
- And many more (36 classes total)

### Liquid Methods
`lib/lutaml/xsd/liquid_methods/` - Modules that add Liquid template helpers to element classes:
- `element.rb` - `used_by`, `attributes`, `child_elements`, `referenced_type`, etc.
- `complex_type.rb` - `used_by`, `child_elements`, `attribute_elements`, etc.
- Other liquid methods for group, choice, sequence, attribute, attribute_group, etc.

### Path/URL Resolution
`lib/lutaml/xsd/glob.rb` - Handles `location` parameter passed to `parse()` for resolving relative paths in `import` and `include` schemaLocation attributes. Supports both local paths and HTTP URLs.

### Model Registration
Classes register themselves via `Lutaml::Xsd.register_model(self, :element_name)` to enable deserialization from XML.

## Key Patterns

1. **Parsing**: `Lutaml::Xsd.parse(xsd_content, location: 'path/')` returns a `Schema` object
2. **Serialization**: All objects support `to_xml` method
3. **Liquid templating**: Parsed objects respond to `to_liquid` for use in templates
4. **Reference resolution**: Elements can reference other elements via `ref` attribute; use `referenced_object` to resolve

### XML Stack: Moxml Only

All XML handling goes through `Moxml::Context` (moxml ~> 0.6.0). Never
require or call Nokogiri/REXML/Ox directly in `lib/` — xsdvi keeps nokogiri
in the lockfile transitively, but our code does not touch it.

- Adapter selection is moxml's: leptris when bundled (dev Gemfile), nokogiri
  fallback otherwise. No adapter is hardcoded here.
- `Moxml::XSD` (engine XSD validation, tier-1: leptris/nokogiri) backs the
  validation fast-path — see `lib/lutaml/xsd/validation/engine_context.rb`.
  Engine findings are additive (`code: "engine_validation"`); the Ruby rule
  engine remains authoritative because tier-1 validates laxly outside its
  scope.

## SPA / Frontend Assets

### Directory Structure
- `frontend/src/` - Vue.js TypeScript source code (committed to git)
- `frontend/dist/` - Built SPA assets (NOT committed to git, built during gem release)

### CRITICAL RULE: lib/ is Ruby Source Only
**`lib/` contains Ruby source code only. Do NOT commit compiled JS/CSS artifacts into `lib/`**.

Built frontend assets (JavaScript, CSS) must NEVER be mixed into `lib/` source directories.

### Gem vs Git: Asset Resolution

**When installed as a gem (RubyGems.org):**
- Frontend assets (`frontend/dist/`) are pre-built and bundled in the gem at the root level
- SPA generation works out of the box, no build required
- Assets are found via path resolution from `lib/lutaml/xsd/spa/strategies/` up to gem root

**When using from git (development):**
- `frontend/dist/` is gitignored and NOT included in the repo
- You MUST build the frontend before running SPA generation:
  ```bash
  bundle exec rake build_frontend
  ```
- Without building, SPA generation raises a clear error explaining the issue

### Release Process
```bash
bundle exec rake release
# 1. Runs build_frontend task (builds frontend → frontend/dist/)
# 2. Gemspec includes frontend/dist/* at gem build time
# 3. Tags version and pushes to RubyGems
```

### Development
```bash
bundle exec rake build_frontend  # Build frontend/dist/ locally
```
