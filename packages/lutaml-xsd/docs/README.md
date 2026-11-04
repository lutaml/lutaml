# lutaml-xsd Documentation

This directory contains the complete documentation for lutaml-xsd, built with Jekyll and the just-the-docs theme using AsciiDoc format.

## Quick Links

- **Live Documentation**: https://www.lutaml.org/lutaml-xsd (after deployment)
- **Source Repository**: https://github.com/lutaml/lutaml-xsd
- **Implementation Plan**: [DOCUMENTATION_PLAN.md](DOCUMENTATION_PLAN.md)

## Local Development

### Prerequisites

- Ruby 3.0 or higher
- Bundler

### Setup

```bash
# Install dependencies
bundle install
```

### Serve Locally

```bash
# Start Jekyll server
bundle exec jekyll serve

# Visit http://localhost:4000/lutaml-xsd in your browser
```

### Build

```bash
# Build static site
bundle exec jekyll build

# Output will be in _site/
```

## Documentation Structure

```
docs/
├── _config.yml              # Jekyll configuration
├── Gemfile                  # Ruby dependencies
├── INDEX.adoc              # Main documentation index
├── INSTALLATION.adoc       # Installation guide
├── QUICK_START.adoc        # Getting started tutorial
├── CLI.adoc               # CLI command reference
├── RUBY_API.adoc          # Ruby API reference (planned)
├── LXR_PACKAGES.adoc      # LXR package concepts (planned)
├── SCHEMA_MAPPINGS.adoc   # Schema mappings (planned)
└── ...                    # Additional documentation files
```

## File Naming Convention

- Use UPPERCASE for top-level documentation files (e.g., `CLI.adoc`)
- Use `.adoc` extension for all content files
- Use descriptive, clear names that match the topic

## Style Guide

### Document Structure

Every documentation file should include:

1. **Front matter** (optional, for navigation control)
2. **Title** (level 1 heading)
3. **TOC** (`:toc:` and `:toclevels: 3`)
4. **Purpose section** - What and who
5. **General section** - Background and overview
6. **Content sections** - Main documentation
7. **See also section** - Cross-references

### Example Template

```asciidoc
= Document Title
:toc:
:toclevels: 3

== Purpose

This document covers {topic} for {audience}.

== General

{Background information and overview}

== Main Section

=== Subsection

.Example Title
[example]
====
[source,ruby]
----
# Code example
----

Explanation of the example.
====

== See also

* link:RELATED[Related Topic]
```

### Writing Guidelines

- **Headings**: Use sentence-case (e.g., "Schema mappings", not "Schema Mappings")
- **Line length**: Wrap at 80 characters (except cross-references, code blocks)
- **Examples**: Always include clear titles and explanations
- **MECE**: Each document covers distinct topic without overlap
- **Consistency**: Use same terminology throughout all documents

### Code Examples

- Wrap code blocks with `[source,language]` and `----`
- Wrap examples with `[example]` and `====`
- Include expected output when relevant
- Use real-world, practical examples
- Test all code examples before publishing

### Cross-References

- Internal links: `link:DOCUMENT[Link Text]`
- Include "See also" section in every document
- Link to prerequisite reading
- Use anchors for deep linking

## Navigation

The documentation uses a 5-level organization:

1. **Getting Started** - Installation, quick start, basics
2. **Basic Usage** - Ruby API, CLI, creating packages
3. **Understanding** - Concepts, architecture, how it works
4. **Customizing** - Configuration options, patterns
5. **Advanced** - Internals, performance, integration

See [INDEX.adoc](INDEX.adoc) for the complete navigation structure.

## Contributing

### Adding New Documentation

1. Create new `.adoc` file following naming convention
2. Use the template structure
3. Add cross-references from INDEX.adoc
4. Link from related documents
5. Test locally with `bundle exec jekyll serve`
6. Verify all examples work
7. Submit pull request

### Updating Existing Documentation

1. Maintain consistency with existing style
2. Update cross-references if needed
3. Test all code examples
4. Verify links still work
5. Update DOCUMENTATION_PLAN.md if adding major content

## Deployment

Documentation is automatically deployed via GitHub Actions when:

- Changes pushed to `main` branch in `docs/` directory
- Manually triggered via workflow_dispatch

See [.github/workflows/docs.yml](../.github/workflows/docs.yml) for deployment configuration.

## Maintenance

### Regular Tasks

- **Monthly**: Verify code examples work with current gem version
- **Per Release**: Update version-specific content
- **Quarterly**: Validate all links
- **Annually**: Consistency audit

### Review Checklist

Before publishing documentation:

- [ ] Follows template structure
- [ ] Uses sentence-case headings
- [ ] Contains working code examples
- [ ] Includes clear explanations
- [ ] Has cross-references
- [ ] Lines wrapped at 80 characters
- [ ] MECE principle applied
- [ ] Terminology consistent
- [ ] All links verified
- [ ] TOC included

## Troubleshooting

### Jekyll won't start

```bash
# Clear cache and reinstall
rm -rf .jekyll-cache _site
bundle install
bundle exec jekyll serve
```

### Changes not showing

```bash
# Force rebuild
bundle exec jekyll clean
bundle exec jekyll serve
```

### Build fails in CI

- Check Ruby version matches (3.2)
- Verify all links are valid
- Ensure no syntax errors in AsciiDoc

## Resources

- **Just the Docs Theme**: https://just-the-docs.com/
- **Jekyll Documentation**: https://jekyllrb.com/docs/
- **AsciiDoc Syntax**: https://asciidoc.org/
- **Canon Documentation** (reference): https://github.com/lutaml/canon/tree/main/docs

## Support

- **Issues**: https://github.com/lutaml/lutaml-xsd/issues
- **Discussions**: https://github.com/lutaml/lutaml-xsd/discussions