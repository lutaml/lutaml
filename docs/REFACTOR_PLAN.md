# Documentation Refactoring Plan

## Goal
Refactor LutaML documentation into a Jekyll-based 4-collection structure following industry best practices.

## Current State Analysis

### User Documentation (Keep & Restructure)
1. **README.adoc** (2015 lines) - Comprehensive guide, needs to be split
2. **diagram-generation.adoc** - Guide for EA diagram generation
3. **diagram-configuration.adoc** - Configuration reference
4. **lutaml-uml.adoc** - UML language guide
5. **lutaml-express.adoc** - EXPRESS parsing
6. **lutaml-xmi.adoc** - XMI parsing
7. **lutaml_syntax.adoc** - Syntax reference
8. **ea_qea_structure.adoc** - QEA format specification
9. **package_metadata.adoc** - Metadata configuration

### Internal Documentation (Archive)
- CLI_THOR_ARCHITECTURE.md
- COMPREHENSIVE_VALIDATION_PLAN.md
- CONTINUATION_PROMPT.txt
- DIAGRAM_SUPPORT_IMPLEMENTATION.md
- IMPLEMENTATION_PLAN.md
- NOTE_OBJECT_ARCHITECTURE.md
- QEA_PARSER_IMPLEMENTATION_STATUS.md
- SPA_CONTINUATION_PLAN.md
- svg_comparison_results.md
- TWO_PHASE_VALIDATION_IMPLEMENTATION.md
- VALIDATION_ARCHITECTURE_REDESIGN.md
- architecture/SPA_ARCHITECTURE.md
- features/SPA_BROWSER.md

## Target Structure

### Collection 1: Core Topics (_pages/)
**Purpose**: Fundamental concepts and essential information

- `index.adoc` - Core Topics Overview
- `overview.adoc` - What is LutaML
- `installation.adoc` - Installation guide
- `architecture.adoc` - System architecture
- `concepts/` - Core concepts directory
  - `qea-parsing.adoc` - QEA direct parsing
  - `lur-format.adoc` - LUR package format
  - `uml-models.adoc` - UML model structure
  - `diagram-generation.adoc` - Diagram generation overview

### Collection 2: Tutorials (_tutorials/)
**Purpose**: Step-by-step learning paths

- `index.adoc` - Tutorials Overview
- `getting-started.adoc` - Quick start tutorial
- `first-lur-package.adoc` - Building your first LUR
- `generating-diagrams.adoc` - Creating diagrams
- `documentation-site.adoc` - Building a docs site
- `querying-models.adoc` - Searching and querying

### Collection 3: Guides (_guides/)
**Purpose**: Task-oriented how-to documentation

- `index.adoc` - Guides Overview
- `cli-usage.adoc` - CLI usage guide
- `diagram-configuration.adoc` - Configuring diagrams
- `package-metadata.adoc` - Package metadata setup
- `repository-management.adoc` - Managing repositories
- `parsing/` - Parsing guides
  - `qea-parsing.adoc` - QEA parsing guide
  - `xmi-parsing.adoc` - XMI parsing guide
  - `express-parsing.adoc` - EXPRESS parsing guide

### Collection 4: References (_references/)
**Purpose**: Detailed technical specifications

- `index.adoc` - References Overview
- `cli/` - CLI reference
  - `commands.adoc` - Complete command reference
  - `build.adoc` - Build command
  - `search.adoc` - Search command
  - `export.adoc` - Export command
- `api/` - API reference
  - `repository.adoc` - Repository API
  - `parsers.adoc` - Parser APIs
  - `presenters.adoc` - Presenter APIs
- `formats/` - Format specifications
  - `qea-structure.adoc` - QEA file format
  - `lur-format.adoc` - LUR package format
  - `lutaml-syntax.adoc` - LutaML syntax
- `configuration/` - Configuration schemas
  - `diagram-styles.adoc` - Diagram styling config
  - `package-metadata.adoc` - Package metadata config

## Implementation Steps

### Phase 1: Setup (Priority 1)
- [x] Create refactoring plan
- [ ] Create directory structure
- [ ] Setup Jekyll _config.yml
- [ ] Create main index.adoc
- [ ] Create collection overview pages

### Phase 2: Content Migration (Priority 1)
- [ ] Migrate core topics to _pages/
- [ ] Create tutorials from README examples
- [ ] Convert guides
- [ ] Move references

### Phase 3: CI/CD (Priority 2)
- [ ] Add GitHub Actions workflow
- [ ] Setup link checking
- [ ] Create lychee.toml

### Phase 4: Cleanup (Priority 2)
- [ ] Archive internal docs to old-docs/
- [ ] Update cross-references
- [ ] Fix all internal links

### Phase 5: Testing (Priority 3)
- [ ] Test Jekyll build
- [ ] Verify all links
- [ ] Check mobile responsiveness

## Content Mapping

### From README.adoc

**To _pages/:**
- Overview section → overview.adoc
- Installation → installation.adoc
- Architecture intro → architecture.adoc

**To _tutorials/:**
- Quick start → getting-started.adoc
- Basic usage examples → first-lur-package.adoc

**To _guides/:**
- CLI command usage → cli-usage.adoc
- Interactive features → guides/

**To _references/:**
- CLI commands reference → references/cli/commands.adoc
- API reference → references/api/

### Diagram Documentation

**diagram-generation.adoc → Split:**
- Overview/intro → _pages/concepts/diagram-generation.adoc
- Configuration basics → _tutorials/generating-diagrams.adoc
- Advanced configuration → _guides/diagram-configuration.adoc

**diagram-configuration.adoc:**
- All content → _references/configuration/diagram-styles.adoc

### Format Documentation

**ea_qea_structure.adoc:**
- All content → _references/formats/qea-structure.adoc

**lutaml_syntax.adoc:**
- All content → _references/formats/lutaml-syntax.adoc

**package_metadata.adoc:**
- Concept/overview → _pages/concepts/ (brief)
- Setup guide → _guides/package-metadata.adoc
- Full reference → _references/configuration/package-metadata.adoc

## Front Matter Template

Every page needs YAML front matter:

```yaml
---
title: Page Title
parent: Parent Page Title (if nested)
nav_order: 1
---
```

## Principles

1. **Onion Structure**: Information revealed incrementally
2. **3-Click Rule**: Any topic reachable within 3 clicks
3. **Content First**: Focus on user needs, not structure
4. **MECE**: Mutually Exclusive, Collectively Exhaustive
5. **No Orphans**: Every page linked from somewhere

## Navigation Order

Set `nav_order` to create logical flow:
- Core concepts: 1-10
- Getting started: 11-20
- Tutorials: 21-30
- Guides: 31-40
- References: 41-50

## Cross-References

Use relative links:
```adoc
See link:../guides/cli-usage.adoc[CLI Usage Guide]
```

## Testing Checklist

- [ ] All pages have front matter
- [ ] All links work
- [ ] Navigation is logical
- [ ] Mobile responsive
- [ ] Search works
- [ ] Dark/light theme works
- [ ] No 404s
- [ ] Images load
- [ ] Code blocks render
- [ ] Tables format correctly