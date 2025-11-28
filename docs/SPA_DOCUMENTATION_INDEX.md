# UML Browser SPA Documentation Index

This document provides an overview of all SPA browser documentation.

## Documentation Structure

### User Documentation

1. **[Feature Guide](features/SPA_BROWSER.md)** (Primary user documentation)
   - Overview and features
   - Installation (built-in, no separate install needed)
   - Quick start guide
   - Command reference (`build-spa`, `serve`)
   - Configuration options
   - Customization guide
   - Troubleshooting
   - Comprehensive examples

2. **[Main README Section](../README.adoc#uml-browser-spa)** (Quick reference)
   - Overview and key features
   - Quick start examples
   - Command reference
   - Output modes comparison
   - Performance guidelines
   - Browser compatibility
   - Customization basics
   - API usage examples

### Technical Documentation

3. **[Architecture Guide](architecture/SPA_ARCHITECTURE.md)** (For developers)
   - High-level architecture overview
   - Component breakdown and data flow
   - Data model and JSON structure
   - Template system (Liquid)
   - JavaScript architecture
   - Search implementation
   - Build pipeline
   - Extensibility points

## Quick Links

### For End Users

- **Getting Started**: See [Feature Guide - Quick Start](features/SPA_BROWSER.md#quick-start)
- **Commands**: See [Feature Guide - Usage](features/SPA_BROWSER.md#usage) or [README - Command Reference](../README.adoc#command-reference)
- **Troubleshooting**: See [Feature Guide - Troubleshooting](features/SPA_BROWSER.md#troubleshooting)
- **Examples**: See [Feature Guide - Examples](features/SPA_BROWSER.md#examples)

### For Developers

- **Architecture**: See [Architecture Guide](architecture/SPA_ARCHITECTURE.md)
- **API Usage**: See [Feature Guide - API Usage](features/SPA_BROWSER.md#for-developers) or [README - API Usage](../README.adoc#api-usage)
- **Customization**: See [Feature Guide - Customization](features/SPA_BROWSER.md#customization)
- **Templates**: Located in `templates/static_site/`
- **Configuration**: See `config/static_site.yml`

## Key Features

✅ **Single-file SPA** - Self-contained HTML file for easy distribution
✅ **Multi-file site** - Optimized for hosting and version control
✅ **Full-text search** - Powered by lunr.js
✅ **Hierarchical navigation** - Package tree with expand/collapse
✅ **Dark/light themes** - With localStorage persistence
✅ **Keyboard shortcuts** - `/`, `Ctrl+K`, arrow keys
✅ **Responsive design** - Mobile, tablet, desktop
✅ **Zero build deps** - Pure Ruby generation, no Node.js
✅ **Accessible** - WCAG 2.1 AA compliant

## Implementation Status

✅ **Complete** - All features implemented and tested
✅ **Documentation** - Comprehensive user and technical documentation
✅ **CLI Integration** - `lutaml uml build-spa` command
✅ **API Mode** - Live server with `lutaml uml serve`
✅ **Templates** - Liquid templates in `templates/static_site/`
✅ **Configuration** - External YAML configuration
✅ **Tests** - Unit and integration tests

## Files Overview

### Documentation Files
- `docs/features/SPA_BROWSER.md` - User guide (690 lines)
- `docs/architecture/SPA_ARCHITECTURE.md` - Architecture (914 lines)
- `README.adoc` - Quick reference section (926 lines added)

### Implementation Files
- `lib/lutaml/uml_repository/static_site/generator.rb` - Main generator
- `lib/lutaml/uml_repository/static_site/configuration.rb` - Configuration
- `lib/lutaml/uml_repository/static_site/data_transformer.rb` - Data transformation
- `lib/lutaml/uml_repository/static_site/search_index_builder.rb` - Search indexing
- `lib/lutaml/uml_repository/static_site/id_generator.rb` - Stable ID generation
- `templates/static_site/` - Liquid templates and assets
- `config/static_site.yml` - Default configuration

### CLI Integration
- `lib/lutaml/cli/uml_commands.rb` - CLI commands
- `lib/lutaml/uml_repository/web_ui/app.rb` - Live server with SPA

## Version

**Version**: 1.0
**Status**: Production Ready
**Last Updated**: 2024-11-17
