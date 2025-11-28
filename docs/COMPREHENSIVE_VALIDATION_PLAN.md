# Comprehensive Validation Architecture Plan

## 1. Current State Analysis

### ✅ What's Currently Validated

**In DocumentBuilder** ([`lib/lutaml/qea/factory/document_builder.rb`](lib/lutaml/qea/factory/document_builder.rb)):
- Duplicate XMI IDs across all elements
- Association references (member_end_xmi_id, owner_end_xmi_id)

### ❌ What's NOT Currently Validated

**Entity-Level References:**
1. **Class/Object References:**
   - Generalization parent references
   - Attribute type references (to other classes/datatypes)
   - Package references (orphaned objects)

2. **Package References:**
   - Parent package existence
   - Tagged value element references

3. **Diagram References:**
   - Diagram objects referencing non-existent model elements
   - Diagram links referencing non-existent connectors

4. **Operation References:**
   - Return type references
   - Parameter type references

5. **Connector/Association References:**
   - Source/dest object references
   - Connector type lookup references

6. **Constraint References:**
   - Constrained element references
   - Constraint type lookup references

**Database Integrity:**
- Foreign key violations (e.g., package_id pointing to non-existent package)
- Required field violations
- Data type mismatches

## 2. Validation Architecture Design

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Validation System                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         ValidationEngine (Orchestrator)             │    │
│  │  - Coordinates all validators                       │    │
│  │  - Collects and consolidates results               │    │
│  │  - Formats output reports                          │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          ├─── Validators ───┐               │
│                          │                   │               │
│  ┌───────────────────┐  │  ┌──────────────────────────┐   │
│  │ EntityValidator   │◄─┘  │  IntegrityValidator       │   │
│  │ - Per-entity rules│     │  - Cross-entity checks    │   │
│  │ - Reference checks│     │  - Database constraints   │   │
│  └───────────────────┘     └──────────────────────────┘   │
│           │                                                  │
│           ├─── Specific Validators                         │
│           │                                                  │
│  ┌────────┴────────┬──────────┬───────────┬────────────┐  │
│  │                 │          │           │            │  │
│  │ Package      Class    Association  Diagram   Attribute│  │
│  │ Validator   Validator  Validator  Validator  Validator│  │
│  │                                                         │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         ValidationResult                            │    │
│  │  - Severity levels (ERROR/WARNING/INFO)            │    │
│  │  - Categorization (missing_ref, orphaned, etc.)    │    │
│  │  - Element context (what, where, why)              │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         ValidationReport                            │    │
│  │  - Summary statistics                               │    │
│  │  - Grouped findings                                 │    │
│  │  - Multiple output formats (text, JSON, HTML)      │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Validation Scope by Entity Type

#### Package Validation
```ruby
class PackageValidator < EntityValidator
  validates :parent_package_exists
  validates :no_duplicate_names_in_parent
  validates :tagged_value_references
  validates :no_circular_hierarchy
end
```

**Rules:**
- Parent package exists (if parent_id is set)
- No circular package hierarchies
- Tagged values reference valid elements
- No duplicate package names at same level

#### Class Validation
```ruby
class ClassValidator < EntityValidator
  validates :package_exists
  validates :generalization_parent_exists
  validates :attribute_type_references
  validates :operation_references
  validates :constraint_references
  validates :stereotype_exists
end
```

**Rules:**
- Package exists
- Generalization parents exist
- Attribute types exist (classes/datatypes/primitives)
- Operation return types exist
- Constrained elements exist
- Stereotypes exist in stereotype table

#### Association Validation
```ruby
class AssociationValidator < EntityValidator
  validates :member_end_exists
  validates :owner_end_exists
  validates :connector_type_exists
  validates :source_object_exists
  validates :dest_object_exists
end
```

**Rules:**
- Member end class exists
- Owner end class exists
- Source/destination objects exist
- Connector type exists in lookup table

#### Diagram Validation
```ruby
class DiagramValidator < EntityValidator
  validates :package_exists
  validates :diagram_type_exists
  validates :diagram_objects_reference_valid_elements
  validates :diagram_links_reference_valid_connectors
end
```

**Rules:**
- Package exists
- Diagram type exists in lookup table
- All diagram objects reference existing model elements
- All diagram links reference existing connectors

#### Attribute Validation
```ruby
class AttributeValidator < EntityValidator
  validates :parent_object_exists
  validates :type_exists
  validates :stereotype_exists
  validates :classifier_exists
end
```

**Rules:**
- Parent object exists
- Type references valid class/datatype/primitive
- Stereotype exists if set
- Classifier exists if set

## 3. Validation Result Format

### Severity Levels

```ruby
module ValidationSeverity
  ERROR   = :error    # Breaks integrity, must fix
  WARNING = :warning  # May cause issues, should review
  INFO    = :info     # Informational, may be intentional
end
```

### Result Structure

```ruby
class ValidationIssue
  attr_reader :severity    # :error, :warning, :info
  attr_reader :category    # :missing_reference, :orphaned, :duplicate, etc.
  attr_reader :entity_type # :package, :class, :association, etc.
  attr_reader :entity_id   # XMI ID or database ID
  attr_reader :entity_name # Human-readable name
  attr_reader :field       # Which field has the issue
  attr_reader :reference   # What it's trying to reference
  attr_reader :message     # Human-readable description
  attr_reader :location    # Package path or context
end
```

### Example Output

```
================================================================================
VALIDATION REPORT: plateau_v5.1.qea
================================================================================

Summary:
  Total Entities Checked: 1,247
  Errors:   11
  Warnings: 23
  Info:     5

ERRORS (11):

  Missing References (6):
    Association {FA86EB3B-198A-4141-83F6-DE9FACC76425}
      └─ member_end references non-existent class 'GPLR_Compression'
      └─ owner_end references non-existent class 'GPLR_Item'

    Association {B5D1F4AE-56DF-49a5-9431-62E7FC4B6730}
      └─ member_end references non-existent class 'GPLR_CRSSupport'
      └─ owner_end references non-existent class 'GPLR_Item'

  Orphaned Objects (5):
    Class 'GPLR_Compression' {875E3845-6D51-4e95-B034-678BA3687CBD}
      └─ package_id=2898 does not exist in t_package

    Class 'GPLR_Item' {6FF5FEEC-4B66-42e8-A3CD-6203BD9C5F47}
      └─ package_id=2898 does not exist in t_package

WARNINGS (23):

  Filtered Objects (2):
    ProxyConnector {53ED6341-10CF-4e13-A4F9-CC4271FD2997}
      └─ object_type='ProxyConnector' not recognized as UML class
      └─ In package: アピアランスモデル (ID: 56)
      └─ Will not be included in transformation

  Missing Stereotypes (21):
    Class 'Building' references undefined stereotype 'FeatureType'
    ...

INFO (5):
  Empty Packages (5):
    Package 'Deprecated' contains no objects or child packages

================================================================================
RECOMMENDATIONS:
  1. Fix orphaned GPLR_* classes: Either restore package 2898 or reassign to valid package
  2. Review ProxyConnector: Decide if should be included in transformation
  3. Consider adding missing stereotypes to t_stereotypes table
================================================================================
```

## 4. Integration Points

### 4.1 Build-Time Validation

**In DocumentBuilder:**
```ruby
# lib/lutaml/qea/factory/document_builder.rb

def build(validate: true, validation_options: {})
  if validate
    engine = Lutaml::Qea::Validation::ValidationEngine.new(@document)
    result = engine.validate(**validation_options)

    # Display warnings/errors
    result.display(verbose: validation_options[:verbose])

    # Optionally fail on errors
    if validation_options[:strict] && result.has_errors?
      raise ValidationError, result.summary
    end
  end

  @document
end
```

**In EaToUmlFactory:**
```ruby
# lib/lutaml/qea/factory/ea_to_uml_factory.rb

def create_document
  builder = DocumentBuilder.new(name: options[:document_name])

  # ... build document ...

  # Validate with configured options
  builder.build(
    validate: options[:validate],
    validation_options: {
      verbose: options[:verbose_validation],
      strict: options[:strict_validation],
      report_format: options[:validation_report_format]
    }
  )
end
```

### 4.2 Standalone Validation

**CLI Command:**
```bash
# Validate QEA file
lutaml validate input.qea

# Validate LUR file
lutaml validate input.lur

# Output formats
lutaml validate input.qea --format=text
lutaml validate input.qea --format=json > report.json
lutaml validate input.qea --format=html > report.html

# Severity filtering
lutaml validate input.qea --errors-only
lutaml validate input.qea --min-severity=warning

# Category filtering
lutaml validate input.qea --category=missing_references
lutaml validate input.qea --category=orphaned

# Strict mode (exit code 1 on errors)
lutaml validate input.qea --strict
```

**API:**
```ruby
# Programmatic validation
validator = Lutaml::Qea::Validation::Validator.new
result = validator.validate_file('input.qea')

if result.has_errors?
  puts result.to_text
  exit 1
end

# Export report
File.write('report.json', result.to_json)
File.write('report.html', result.to_html)
```

## 5. Implementation Plan

### Phase 1: Core Infrastructure (Week 1)
- [x] Create ValidationEngine base class
- [x] Create ValidationIssue model
- [x] Create ValidationResult/Report classes
- [x] Implement text output format
- [x] Create base EntityValidator class

### Phase 2: Entity Validators (Week 2)
- [ ] Implement PackageValidator
- [ ] Implement ClassValidator
- [ ] Implement AssociationValidator
- [ ] Enhance existing association validation
- [ ] Implement AttributeValidator
- [ ] Implement DiagramValidator

### Phase 3: Database Integrity (Week 2-3)
- [ ] Implement IntegrityValidator
- [ ] Add foreign key checks
- [ ] Add orphaned object detection
- [ ] Add circular reference detection

### Phase 4: Integration (Week 3)
- [ ] Integrate with DocumentBuilder
- [ ] Integrate with EaToUmlFactory
- [ ] Add validation options to configuration

### Phase 5: Standalone Validation (Week 4)
- [ ] Create CLI validate command
- [ ] Implement JSON output format
- [ ] Implement HTML output format
- [ ] Add filtering and reporting options
- [ ] Create validation for LUR files

### Phase 6: Documentation & Testing (Week 4)
- [ ] Write comprehensive tests
- [ ] Document validation rules
- [ ] Create user guide
- [ ] Add examples

## 6. File Structure

```
lib/lutaml/qea/validation/
├── validation_engine.rb          # Main orchestrator
├── validation_issue.rb           # Issue model
├── validation_result.rb          # Result collection
├── validation_report.rb          # Report formatting
├── entity_validator.rb           # Base validator
├── integrity_validator.rb        # Cross-entity checks
├── validators/
│   ├── package_validator.rb
│   ├── class_validator.rb
│   ├── association_validator.rb
│   ├── attribute_validator.rb
│   ├── diagram_validator.rb
│   ├── operation_validator.rb
│   └── connector_validator.rb
└── formatters/
    ├── text_formatter.rb
    ├── json_formatter.rb
    └── html_formatter.rb
```

## 7. Configuration

```yaml
# config/validation.yml
validation:
  # Default settings
  enabled: true
  strict: false
  verbose: false

  # Severity settings
  min_severity: warning  # error, warning, info

  # Category filters
  categories:
    - missing_references
    - orphaned_objects
    - duplicate_ids
    - invalid_types
    - circular_references

  # Entity-specific rules
  rules:
    packages:
      check_parent_exists: true
      check_circular_hierarchy: true
      check_duplicate_names: true

    classes:
      check_package_exists: true
      check_parent_classes: true
      check_attribute_types: true
      warn_on_missing_stereotypes: true

    associations:
      check_member_end: true
      check_owner_end: true
      check_source_dest: true

    diagrams:
      check_package_exists: true
      check_diagram_objects: true
      check_diagram_links: true

  # Output settings
  output:
    format: text  # text, json, html
    group_by: category  # category, severity, entity_type
    show_recommendations: true
```

## 8. Success Criteria

- ✅ All entity reference types validated
- ✅ Database integrity issues detected
- ✅ Clear, actionable error messages
- ✅ Build-time validation integrated
- ✅ Standalone validation command available
- ✅ Multiple output formats supported
- ✅ Configurable severity and filtering
- ✅ Comprehensive test coverage
- ✅ Documentation complete