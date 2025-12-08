# LutaML Documentation

This directory contains the LutaML documentation website built with Jekyll and the just-the-docs theme.

## 🎉 Jekyll Site Structure: READY

The documentation framework is complete and ready for content migration.

## Quick Start

### Local Development

```bash
cd docs
bundle install
bundle exec jekyll serve
```

Open http://localhost:4000/lutaml/

### Production Build

```bash
cd docs
JEKYLL_ENV=production bundle exec jekyll build
```

Output in `_site/` directory.

## Site Structure

```
docs/
├── index.adoc                  # Homepage ✅
├── _config.yml                 # Jekyll configuration ✅
├── Gemfile                     # Dependencies ✅
├── lychee.toml                # Link checker config ✅
│
├── _pages/                     # Core Topics collection ✅
│   ├── index.adoc             # Collection overview
│   └── concepts/              # Concepts subdirectory
│
├── _tutorials/                 # Tutorials collection ✅
│   └── index.adoc             # Collection overview
│
├── _guides/                    # Guides collection ✅
│   ├── index.adoc             # Collection overview
│   └── parsing/               # Parsing guides subdirectory
│
├── _references/                # Reference collection ✅
│   ├── index.adoc             # Collection overview
│   ├── cli/                   # CLI reference
│   ├── api/                   # API reference
│   ├── formats/               # Format specifications
│   └── configuration/         # Configuration schemas
│
└── .github/workflows/          # CI/CD ✅
    ├── docs.yml               # Build and deploy
    └── links.yml              # Link checking
```

## Documentation Collections

### 1. Core Topics (_pages/)

Fundamental concepts and essential information.

**Status**: Skeleton ready, content needs migration

### 2. Tutorials (_tutorials/)

Step-by-step learning paths with complete workflows.

**Status**: Overview ready, tutorials need creation

### 3. Guides (_guides/)

Task-oriented how-to documentation.

**Status**: Overview ready, guides need migration

### 4. Reference (_references/)

Detailed technical specifications and API docs.

**Status**: Structure ready, content needs migration

## Next Steps

See [`MIGRATION_GUIDE.md`](MIGRATION_GUIDE.md) for detailed instructions on:

1. Content migration from existing docs
2. Front matter requirements
3. Link updating procedures
4. Testing checklist

See [`REFACTOR_PLAN.md`](REFACTOR_PLAN.md) for complete categorization and mapping.

## Contributing

### Adding a New Page

1. Create file in appropriate collection directory
2. Add YAML front matter:
   ```yaml
   ---
   title: Page Title
   parent: Parent Page Title
   nav_order: 1
   ---
   ```
3. Write content in AsciiDoc format
4. Test locally: `bundle exec jekyll serve`
5. Submit pull request

### Updating Existing Pages

1. Edit the `.adoc` file
2. Update cross-references if needed
3. Test build locally
4. Submit pull request

## GitHub Actions

### Build and Deploy (docs.yml)

Automatically builds and deploys on push to main.

**Triggers**: Push to main, pull requests, manual dispatch

### Link Checking (links.yml)

Validates all links in documentation.

**Triggers**: Push to main, pull requests, weekly schedule

## Link Syntax

Use AsciiDoc format for all internal links:

```adoc
link:relative/path.adoc[Link Text]
link:../_pages/installation.adoc[Installation Guide]
```

## Front Matter Reference

### Top-level page:
```yaml
---
title: Page Title
nav_order: 1
---
```

### Child page:
```yaml
---
title: Child Page
parent: Parent Page Title
nav_order: 2
---
```

### Grandchild:
```yaml
---
title: Grandchild
parent: Child Page Title
grand_parent: Parent Page Title
nav_order: 1
---
```

## Configuration

### Site Settings (_config.yml)

- Title: LutaML Documentation
- Base URL: /lutaml
- Theme: just-the-docs 0.7.0
- 4 collections configured
- Search enabled
- Link checking enabled

### Dependencies (Gemfile)

- jekyll (~> 4.3)
- just-the-docs (0.7.0)
- jekyll-asciidoc
- jekyll-seo-tag
- jekyll-sitemap

### Link Checker (lychee.toml)

- Caching enabled
- Follows redirects
- Excludes examples and localhost
- Retry logic for rate limits

## Common Commands

```bash
# Install dependencies
bundle install

# Serve locally with live reload
bundle exec jekyll serve --livereload

# Build for production
JEKYLL_ENV=production bundle exec jekyll build

# Check links
bundle exec jekyll build
lychee --config lychee.toml '_site/**/*.html'

# Clean build artifacts
bundle exec jekyll clean
```

## Troubleshooting

### "Liquid Exception: Included file '_includes/head.html' not found"

Install theme: `bundle install`

### Links showing as [link text](broken_path)

Use AsciiDoc syntax: `link:path.adoc[Text]`

### Navigation not showing pages

Check front matter `parent` matches parent `title` exactly.

### Search not working

Rebuild site to regenerate search index.

## Resources

- **Jekyll**: https://jekyllrb.com/docs/
- **Just the Docs**: https://just-the-docs.github.io/just-the-docs/
- **AsciiDoc**: https://docs.asciidoctor.org/asciidoc/latest/
- **Migration Guide**: [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
- **Refactor Plan**: [REFACTOR_PLAN.md](REFACTOR_PLAN.md)

## Status

**Infrastructure**: ✅ Complete  
**Content Migration**: 📝 In Progress  
**Testing**: ⏳ Pending  
**Deployment**: 🚀 Ready
