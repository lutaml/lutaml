# QEA Parser - Enterprise Architect Database Parser

A Ruby library for parsing Enterprise Architect .qea (SQLite) database files into structured Ruby objects using Lutaml::Model.

## Overview

This library provides a complete object-oriented model for Enterprise Architect's database schema, allowing you to:

- Load QEA files into Ruby objects
- Access UML model elements (classes, attributes, operations, connectors, packages, diagrams)
- Query and analyze Enterprise Architect models programmatically
- Verify data integrity and completeness

## Architecture

### Model-Based Design

The library uses a fully model-driven architecture with:

- **94 Model Classes**: One class for each Enterprise Architect table
- **Lutaml::Model**: For serialization and type safety
- **Registry Pattern**: Central mapping of tables to classes
- **Dynamic Database Container**: Flexible storage for all collections
- **Separation of Concerns**: Models, Loader, and Verifier are distinct

### Class Structure

```
lib/qea/
├── models/              # 94 model classes (one per table)
│   ├── base.rb         # Base class for all models
│   ├── object.rb       # EaObject (t_object)
│   ├── attribute.rb    # EaAttribute (t_attribute)
│   ├── connector.rb    # EaConnector (t_connector)
│   ├── package.rb      # EaPackage (t_package)
│   ├── operation.rb    # EaOperation (t_operation)
│   ├── diagram.rb      # EaDiagram (t_diagram)
│   └── ...             # 88 more model classes
├── registry.rb         # Table-to-class mapping
├── loader.rb           # Database loading logic
└── generate_models.rb  # Model generator utility
```

## Installation

```bash
gem install lutaml-model sqlite3
```

## Usage

### Basic Usage

```ruby
require_relative 'lib/qea'

# Load a QEA file
database = Qea.load('path/to/file.qea')

# Access collections
puts "Objects: #{database.objects.size}"
puts "Attributes: #{database.attributes.size}"
puts "Connectors: #{database.connectors.size}"
puts "Packages: #{database.packages.size}"

# Get statistics
stats = database.stats
stats.each do |table_name, count|
  puts "#{table_name}: #{count} records"
end

# Total records
puts "Total records: #{database.total_records}"
```

### Working with Model Elements

```ruby
# Access UML objects (classes, interfaces, etc.)
database.objects.each do |obj|
  puts "Object: #{obj.name} (#{obj.object_type})"
  puts "  GUID: #{obj.ea_guid}"
  puts "  Package ID: #{obj.package_id}"
  puts "  Stereotype: #{obj.stereotype}"
end

# Access attributes
database.attributes.each do |attr|
  puts "Attribute: #{attr.name}"
  puts "  Type: #{attr.type}"
  puts "  Scope: #{attr.scope}"
end

# Access connectors (relationships)
database.connectors.each do |conn|
  puts "Connector: #{conn.name || 'unnamed'}"
  puts "  Type: #{conn.connector_type}"
  puts "  From: #{conn.start_object_id}"
  puts "  To: #{conn.end_object_id}"
end

# Access packages
database.packages.each do |pkg|
  puts "Package: #{pkg.name}"
  puts "  Parent ID: #{pkg.parent_id}"
  puts "  GUID: #{pkg.ea_guid}"
end
```

### Available Collections

The Database object provides access to all 94 EA tables through dynamically-created accessors:

**Core UML Model:**
- `objects` - UML objects (classes, interfaces, components, etc.)
- `attributes` - Class attributes and properties
- `operations` - Class operations and methods
- `operationparams` - Operation parameters
- `connectors` - Relationships between objects
- `packages` - UML packages and namespaces
- `diagrams` - UML diagrams

**Extended Model:**
- `taggedvalues` - Tagged values (stereotypes, metadata)
- `stereotypes` - Stereotype definitions
- `datatypes` - Data type definitions
- `constraints` - Model constraints
- And 80+ more collections...

## Verification

Use the included verification script to validate QEA files:

```bash
./verify_qea.rb path/to/file.qea

# Or verify multiple files
./verify_qea.rb file1.qea file2.qea file3.qea
```

### Verification Features

- Confirms file exists and is readable
- Loads all tables and counts records
- Checks foreign key integrity
- Reports statistics and warnings
- Aggregate statistics across multiple files

### Example Verification Output

```
================================================================================
Verifying: model.qea
================================================================================

File: model.qea
  Exists: ✓
  Loaded: ✓
  Tables with data: 41/94
  Total records: 12445

  Top tables by record count:
    t_attribute                      1910 records
    t_diagramlinks                   1813 records
    t_diagramobjects                 1767 records
    t_objectproperties               1537 records
    t_xref                           1246 records

  ✓ All checks passed
```

## Tested QEA Files

The library has been successfully tested with:

1. **UmlModel_template.qea** - 995 records, 26 tables
2. **ArcGISWorkspace_template.qea** - 993 records, 31 tables
3. **ShapeChangeMDG.qea** - 1,130 records, 35 tables
4. **20251010_current_plateau_v5.0_Ron-san-Modify.qea** - 12,445 records, 41 tables

**Total verified: 15,563 records across 4 files**

## Model Classes

Each EA table has a corresponding Ruby model class:

| Table | Class | Description |
|-------|-------|-------------|
| t_object | Qea::Models::Object | UML objects |
| t_attribute | Qea::Models::Attribute | Class attributes |
| t_connector | Qea::Models::Connector | Relationships |
| t_package | Qea::Models::Package | Packages |
| t_operation | Qea::Models::Operation | Operations |
| t_diagram | Qea::Models::Diagram | Diagrams |
| ... | ... | 88 more classes |

### Model Features

- **Type Safety**: All attributes are typed (integer, string, float, boolean)
- **Primary Keys**: Accessible via `id` method
- **Column Mapping**: Automatic mapping from SQLite columns to Ruby attributes
- **Reserved Word Handling**: Special handling for Ruby keywords (`default`, `constraint`)

## Code Generation

The library includes utilities to generate model classes from QEA schema:

```bash
# Generate all model classes from a QEA file
ruby lib/qea/generate_models.rb path/to/file.qea

# Generate Database attribute list
ruby lib/qea/generate_database_attrs.rb
```

## Implementation Details

### Key Design Principles

1. **MECE (Mutually Exclusive, Collectively Exhaustive)**: Each model handles one table exclusively
2. **Model-Based Architecture**: All data represented as Lutaml::Model classes
3. **Registry Pattern**: Centralized table-to-class mapping
4. **Separation of Concerns**: Clear boundaries between models, loading, and verification
5. **Extensibility**: Easy to add new functionality or model classes

### Performance

- Read-only database access (safe for concurrent use)
- Lazy loading not implemented (all tables loaded on initialization)
- Suitable for files up to ~15,000 records (tested)
- For larger files, consider selective table loading

## Limitations

- Read-only (no write support)
- No lazy loading (entire database loaded at once)
- Some Lutaml warnings for attributes conflicting with Ruby builtins (`object_id`, `methods`)
- Binary columns (BLOBs) not fully supported

## Future Enhancements

Potential improvements:

1. **Relationship Navigation**: Direct object references (e.g., `attr.object` instead of `attr.object_id`)
2. **Lazy Loading**: Load tables on-demand
3. **Query DSL**: Fluent API for querying models
4. **Write Support**: Create/update QEA files
5. **Export Formats**: Export to JSON, YAML, XML
6. **UML Analysis**: Higher-level UML model analysis tools

## License

This library is provided as-is for parsing Enterprise Architect database files.

## Credits

- Built with [Lutaml::Model](https://github.com/lutaml/lutaml-model)
- Uses SQLite3 for database access
- Part of the ShapeChange project ecosystem
