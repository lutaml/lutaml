# Lutaml-XSD Examples

This directory contains practical examples demonstrating various features of lutaml-xsd, organized by complexity and use case.

## MECE Organization

The examples follow a **Mutually Exclusive, Collectively Exhaustive (MECE)** structure with four categories:

### 1. [Simple Schemas](01-simple/)
**Complexity: ★☆☆☆☆** | **Dependencies: None**

Basic schemas with no imports or includes. Perfect starting point.

- Simple person and company schemas
- Single namespace handling
- Basic build, search, and resolve operations
- ~10 types, 2 schemas

**When to use:** Learning lutaml-xsd basics, testing simple workflows

**Read more:** [01-simple/README.adoc](01-simple/README.adoc)

### 2. [Urban Function (i-UR)](02-urban-function/)
**Complexity: ★★★★☆** | **Dependencies: Many imports/includes**

Complex real-world schemas with extensive dependencies from Japanese urban planning standards.

- 200+ types across 50+ schemas
- Complex import chains (GML, ISO 19139, CityGML)
- Schema location mapping patterns
- Multi-namespace resolution

**When to use:** Working with enterprise standards, geographic data, complex dependencies

**Read more:** [02-urban-function/README.adoc](02-urban-function/README.adoc)

### 3. [UnitsML](03-unitsml/)
**Complexity: ★★☆☆☆** | **Dependencies: Self-contained**

Scientific standard for units of measure with specialized vocabulary.

- OASIS standard schema
- Scientific/technical vocabulary
- 30-50 unit-related types
- Clean single-file structure

**When to use:** Scientific computing, measurement systems, domain-specific vocabularies

**Read more:** [03-unitsml/README.adoc](03-unitsml/README.adoc)

### 4. [Metaschema (NIST)](04-metaschema/)
**Complexity: ★★★★★** | **Dependencies: Schema includes**

Self-referential schema defining the Metaschema modeling language itself.

- Meta-level modeling (schemas defining schemas)
- Recursive type definitions
- NIST OSCAL foundation
- Advanced constraint system

**When to use:** Meta-modeling, OSCAL development, advanced schema patterns

**Read more:** [04-metaschema/README.adoc](04-metaschema/README.adoc)

## Quick Start

Each category contains:

```
{category}/
├── README.adoc          # Detailed documentation
├── config.yml           # Package configuration
├── schemas/             # XSD schema files (or references)
├── ruby-api/            # Ruby API examples
│   └── example.rb
└── cli/                 # Command-line examples
    └── run.sh
```

### Running Examples

**Ruby API:**
```bash
ruby examples/01-simple/ruby-api/example.rb
ruby examples/02-urban-function/ruby-api/example.rb
ruby examples/03-unitsml/ruby-api/example.rb
ruby examples/04-metaschema/ruby-api/example.rb
```

**CLI:**
```bash
bash examples/01-simple/cli/run.sh
bash examples/02-urban-function/cli/run.sh
bash examples/03-unitsml/cli/run.sh
bash examples/04-metaschema/cli/run.sh
```

## Learning Path

### Beginner Path
1. Start with [01-simple](01-simple/) to learn basics
2. Read the [Ruby API documentation](../docs/RUBY_API.adoc)
3. Try [03-unitsml](03-unitsml/) for real-world single-file schemas

### Intermediate Path
1. Complete beginner path
2. Explore [02-urban-function](02-urban-function/) for complex dependencies
3. Study schema location mapping patterns
4. Review [package configuration](../docs/PACKAGE_CONFIGURATION.adoc)

### Advanced Path
1. Complete intermediate path
2. Study [04-metaschema](04-metaschema/) for self-referential schemas
3. Explore meta-modeling concepts
4. Apply patterns to your own schemas

## Common Operations

### Building Packages

**From configuration file:**
```bash
lutaml-xsd pkg build config.yml -o output.lxr
```

**Ruby API:**
```ruby
repository = Lutaml::Xsd::SchemaRepository.new
repository.instance_variable_set(:@files, schema_files)
repository.configure_namespace(prefix: "p", uri: "http://example.com/person")
repository.parse.resolve
repository.to_package("output.lxr",
  xsd_mode: :include_all,
  resolution_mode: :resolved,
  serialization_format: :marshal)
```

### Searching Types

**CLI:**
```bash
lutaml-xsd search TypeName package.lxr --limit 10
```

**Ruby API:**
```ruby
searcher = Lutaml::Xsd::TypeSearcher.new(repository)
results = searcher.search("TypeName", in_field: "name", limit: 10)
```

### Resolving Types

**CLI:**
```bash
lutaml-xsd type prefix:TypeName package.lxr
```

**Ruby API:**
```ruby
result = repository.find_type("prefix:TypeName")
if result.resolved?
  puts result.definition
end
```

## Additional Examples

### 5. [Schema Validation](05-schema-validation/)
**Complexity: ★☆☆☆☆** | **Feature: XSD Validation**

Pre-parsing validation of XSD schema files with version detection.

- Validate XSD 1.0 and 1.1 schemas
- Automatic version detection
- Multiple output formats (text, JSON, YAML)
- CI/CD integration examples

**When to use:** Validating schemas before parsing, CI/CD pipelines, pre-commit hooks

**Read more:** [05-schema-validation/README.adoc](05-schema-validation/README.adoc)

### 6. [Package Composition](06-package-composition/)
**Complexity: ★★★☆☆** | **Feature: Multi-package Management**

Combining multiple LXR packages with conflict detection and resolution.

- Merge multiple LXR packages
- Conflict resolution strategies (keep, override, error)
- Priority-based merging
- Namespace remapping
- Schema filtering with glob patterns

**When to use:** Managing multiple schema sources, enterprise schema integration, version migration

**Read more:** [06-package-composition/README.adoc](06-package-composition/README.adoc)

### 7. [Package Merge](07-package-merge/)
**Complexity: ★★☆☆☆** | **Feature: Base + Generated Schemas**

Merging base LXR packages with newly generated XSD files.

- Combine base packages (GML, ISO standards) with generated schemas
- Integration with lutaml-klin UML-to-XSD workflow
- PLATEAU-style 3-process workflow
- Reproducible builds from configuration

**When to use:** UML-to-XSD workflows, combining standards with domain schemas, PLATEAU projects

**Read more:** [07-package-merge/README.adoc](07-package-merge/README.adoc)

### Validation Examples
The `validation/` directory contains XML validation examples:
- [validate_xml_basic.rb](validation/validate_xml_basic.rb) - Basic validation
- [validate_xml_advanced.rb](validation/validate_xml_advanced.rb) - Advanced validation with config
- [validate_with_suggestions.rb](validation/validate_with_suggestions.rb) - Error suggestions

See [validation/README](validation/) for details.

### Legacy Examples
Additional examples for reference (maintained for compatibility):
- [lxr_build.rb](lxr_build.rb) - Package building
- [lxr_search.rb](lxr_search.rb) - Type searching
- [lxr_type_resolution.rb](lxr_type_resolution.rb) - Type resolution

## Features Demonstrated

### Core Features
- ✓ Building LXR packages from XSD schemas
- ✓ Package serialization (Marshal, JSON, YAML)
- ✓ Type searching with relevance ranking
- ✓ Type resolution by qualified name
- ✓ Namespace management
- ✓ Schema location mapping
- ✓ Package statistics and metadata

### Advanced Features
- ✓ Complex schema dependencies (imports/includes)
- ✓ Schema location mapping patterns
- ✓ Batch type queries
- ✓ Type hierarchy analysis
- ✓ Self-referential schemas
- ✓ Namespace-aware operations
- ✓ Package tree visualization

## Configuration Patterns

### Simple Configuration
```yaml
files:
  - schema1.xsd
  - schema2.xsd

namespace_mappings:
  - prefix: "ns1"
    uri: "http://example.com/ns1"
```

### Complex Configuration with Mappings
```yaml
files:
  - main.xsd

schema_location_mappings:
  # Direct mapping
  - from: "../../dep.xsd"
    to: /path/to/local/dep.xsd

  # Pattern mapping (regex)
  - from: '(?:\.\./)+(lib/.+\.xsd)$'
    to: /path/to/lib/\1
    pattern: true

namespace_mappings:
  - prefix: "main"
    uri: "http://example.com/main"
```

## Troubleshooting

### Package Build Failures

**Import resolution errors:**
- Check schema location mappings
- Verify fixture files exist
- Use absolute paths in mappings

**Namespace conflicts:**
- Review namespace mappings
- Check for duplicate prefixes
- Verify URI consistency

### Performance Issues

**Large schemas:**
- Use Marshal serialization (fastest)
- Enable caching for development
- Consider resolution mode options

**Slow searches:**
- Limit result count
- Use specific search fields
- Consider indexed queries

## Next Steps

1. Choose a category matching your complexity level
2. Run the examples (Ruby API and CLI)
3. Read the category-specific README
4. Experiment with your own schemas
5. Explore advanced documentation

## Documentation

- [Ruby API Reference](../docs/RUBY_API.adoc)
- [CLI Commands](../docs/CLI.adoc)
- [Package Configuration](../docs/PACKAGE_CONFIGURATION.adoc)
- [Schema Mappings](../docs/SCHEMA_MAPPINGS.adoc)
- [Type Resolution](../docs/core-concepts/TYPE_RESOLUTION.adoc)

## Legacy Examples (Deprecated)

The following root-level examples are deprecated and will be removed:
- `lxr_build.rb` - Replaced by category-specific examples
- `lxr_search.rb` - Replaced by category-specific examples
- `lxr_type_resolution.rb` - Replaced by category-specific examples
- Old examples have been moved to `archive-old/`

Please use the MECE-organized examples in `01-simple/` through `04-metaschema/` instead.

## Contributing

When adding new examples:
1. Follow the MECE category structure
2. Include both Ruby API and CLI examples
3. Write comprehensive README.adoc files
4. Add configuration files
5. Update this main README

## Support

For issues or questions:
- Check category-specific READMEs
- Review documentation in `docs/`
- Open an issue on GitHub
- Refer to existing examples

---

**MECE Categories:** [01-simple](01-simple/) | [02-urban-function](02-urban-function/) | [03-unitsml](03-unitsml/) | [04-metaschema](04-metaschema/) | [05-schema-validation](05-schema-validation/) | [06-package-composition](06-package-composition/) | [07-package-merge](07-package-merge/) | [validation](validation/)