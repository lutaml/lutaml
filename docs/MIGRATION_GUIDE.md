# Documentation Migration Guide

## Status: Foundation Complete ✅

The Jekyll documentation structure has been established. Content migration is the next step.

## What's Been Set Up

### ✅ Complete Infrastructure

1. **Jekyll Configuration** - `_config.yml`, `Gemfile`, `lychee.toml`
2. **Directory Structure** - All 4 collections with subdirectories
3. **Collection Overviews** - Index pages for all collections
4. **CI/CD Workflows** - GitHub Actions for build and link checking
5. **Main Homepage** - `docs/index.adoc` with navigation

## Quick Start

```bash
cd docs
bundle install
bundle exec jekyll serve
# Open http://localhost:4000/lutaml/
```

## Content Migration Priorities

### Priority 1: Essential Content

**From README.adoc** → Split into:
- `_pages/overview.adoc` - What is LutaML
- `_pages/installation.adoc` - Install guide
- `_tutorials/getting-started.adoc` - Quick start
- `_guides/cli-usage.adoc` - CLI usage
- `_references/cli/commands.adoc` - CLI reference
- `_references/api/repository.adoc` - API docs

**Technical Docs** → Move to _references/:
- `ea_qea_structure.adoc` → `_references/formats/qea-structure.adoc`
- `lutaml_syntax.adoc` → `_references/formats/lutaml-syntax.adoc`
- `diagram-configuration.adoc` → `_references/configuration/diagram-styles.adoc`
- `package_metadata.adoc` → `_references/configuration/package-metadata.adoc`

**User Guides** → Move/adapt:
- `diagram-generation.adoc` → Split across pages/tutorials/guides
- `lutaml-uml.adoc` → `_guides/uml-modeling.adoc`
- `lutaml-express.adoc` → `_guides/parsing/express-parsing.adoc`
- `lutaml-xmi.adoc` → `_guides/parsing/xmi-parsing.adoc`

### Priority 2: Archive Internal Docs

Move to `docs/old-docs/` or delete these planning documents.

## Migration Steps

### 1. Add Front Matter

Every page needs YAML front matter:

```yaml
---
title: Page Title
parent: Parent Page Title
nav_order: 1
---
```

### 2. Update Links

Change relative paths for new structure:

```adoc
# Old
link:diagram-configuration.adoc[Config]

# New
link:../_references/configuration/diagram-styles.adoc[Config]
```

### 3. Test Build

After each file:

```bash
bundle exec jekyll serve
```

## File Structure

```
docs/
├── index.adoc                         # Homepage ✅
├── _pages/                            # Core Topics ✅
│   ├── index.adoc
│   ├── overview.adoc                  # TODO
│   ├── installation.adoc              # TODO
│   ├── architecture.adoc              # TODO
│   └── concepts/
│       ├── qea-parsing.adoc          # TODO
│       ├── lur-format.adoc           # TODO
│       └── diagram-generation.adoc    # TODO
├── _tutorials/                        # Tutorials ✅
│   ├── index.adoc
│   ├── getting-started.adoc          # TODO
│   ├── first-lur-package.adoc        # TODO
│   └── generating-diagrams.adoc      # TODO
├── _guides/                           # Guides ✅
│   ├── index.adoc
│   ├── cli-usage.adoc                # TODO
│   ├── diagram-configuration.adoc     # TODO
│   └── parsing/
│       ├── qea-parsing.adoc          # TODO
│       ├── xmi-parsing.adoc          # TODO
│       └── express-parsing.adoc      # TODO
└── _references/                       # Reference ✅
    ├── index.adoc
    ├── cli/
    │   └── commands.adoc             # TODO
    ├── api/
    │   └── repository.adoc           # TODO
    ├── formats/
    │   ├── qea-structure.adoc        # Move from ea_qea_structure.adoc
    │   └── lutaml-syntax.adoc        # Move from lutaml_syntax.adoc
    └── configuration/
        ├── diagram-styles.adoc        # Move from diagram-configuration.adoc
        └── package-metadata.adoc      # Move from package_metadata.adoc
```

## Content Guidelines

### Required Page Structure

1. Title (from front matter)
2. **Purpose** - What this page covers
3. **Prerequisites** - What reader needs
4. **References** - Related pages
5. **Main content** - 4+ sections
6. **Examples** - Code examples
7. **See Also** - Bibliography

### Link Syntax

Use AsciiDoc format:

```adoc
link:relative/path.adoc[Link Text]
```

### Code Blocks

```adoc
[source,ruby]
----
code here
----
```

## Testing Checklist

- [ ] All pages have front matter
- [ ] All links work (no 404s)
- [ ] Code blocks render correctly
- [ ] Navigation is complete
- [ ] Search works
- [ ] Mobile responsive
- [ ] Link checker passes

## Build Commands

```bash
# Development
bundle exec jekyll serve --livereload

# Production
JEKYLL_ENV=production bundle exec jekyll build

# Link check
lychee --config lychee.toml '_site/**/*.html'
```

## Navigation Order

- 1-10: Core concepts
- 11-20: Getting started
- 21-30: Tutorials
- 31-40: Guides
- 41-50: References

## Common Issues

**Links broken?** Check front matter `parent` matches parent page `title`.

**Navigation missing?** Ensure `nav_order` is set.

**Search empty?** Rebuild site to regenerate index.

## Summary

- **Foundation**: ✅ Complete
- **Content Migration**: 📝 Ready to start
- **Estimated Time**: 4-6 hours
- **See Also**: `REFACTOR_PLAN.md` for details