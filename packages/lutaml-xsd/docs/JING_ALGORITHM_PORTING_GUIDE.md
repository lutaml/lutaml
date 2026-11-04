# Jing Validator Algorithm Porting Guide

**Date:** 2025-10-28
**Purpose:** Strategy for porting XSD validation algorithms from Jing validator to lutaml-xsd

## Overview

This document provides a systematic approach to porting validation algorithms from the Jing validator (Java) to lutaml-xsd (Ruby), ensuring feature parity for XSD schema validation while maintaining clean object-oriented Ruby architecture.

## Reference: Jing Validator Architecture

### Source Location
```
~/src/external/relaxng/mod/validate/src/main/com/thaiopensource/validate/
```

### Key Components to Study

#### 1. Schema Validation Framework
```
validate/
├── Schema.java              # Schema abstraction
├── SchemaReader.java        # Schema loading
├── Validator.java           # Validation interface
├── ValidationDriver.java    # Main validation driver
└── IncorrectSchemaException.java
```

#### 2. XSD-Specific Components
```
validate/xsd/
├── XsdSchema.java           # XSD schema representation
├── XsdSchemaReader.java     # XSD parsing
├── ElementValidator.java    # Element validation
├── AttributeValidator.java  # Attribute validation
└── TypeValidator.java       # Type validation
```

#### 3. Error Handling
```
validate/
├── ValidateProperty.java    # Validation properties
├── ErrorHandler.java        # Error collection
└── DraconianErrorHandler.java
```

## Algorithm Porting Strategy

### Phase 1: Core Validation Algorithms

#### 1.1 Element Validation Algorithm

**Jing Implementation Pattern:**
```java
// Pseudo-code from Jing ElementValidator
public class ElementValidator {
  public void validate(Element element, Schema schema) {
    // Step 1: Validate element declaration exists
    ElementDecl decl = schema.getElementDecl(element.getNamespaceURI(),
                                              element.getLocalName());
    if (decl == null) {
      reportError("element not allowed", element);
      return;
    }

    // Step 2: Validate element type
    TypeValidator typeValidator = getTypeValidator(decl.getType());
    typeValidator.validate(element);

    // Step 3: Validate attributes
    validateAttributes(element, decl);

    // Step 4: Validate children
    validateChildren(element, decl);

    // Step 5: Check occurrence constraints
    validateOccurrences(element, decl);
  }
}
```

**Ruby Port Strategy:**
```ruby
module Lutaml::Xsd::Validation::Rules
  class ElementStructureRule < ValidationRule
    def validate(xml_element, schema_element, collector)
      # Step 1: Validate element declaration exists
      return unless validate_element_exists(xml_element, schema_element, collector)

      # Step 2: Validate element name and namespace
      validate_element_identity(xml_element, schema_element, collector)

      # Step 3: Delegate to type validator
      validate_element_type(xml_element, schema_element, collector)

      # Step 4: Validate attributes
      validate_element_attributes(xml_element, schema_element, collector)

      # Step 5: Validate children according to content model
      validate_element_children(xml_element, schema_element, collector)
    end

    private

    def validate_element_exists(xml_element, schema_element, collector)
      return true if schema_element

      collector.add_error(
        ElementNotAllowedError.new(
          element: xml_element.qualified_name,
          location: xml_element.xpath,
          suggestions: find_similar_elements(xml_element)
        )
      )
      false
    end

    # ... other validation methods
  end
end
```

**Key Differences:**
- Java uses inheritance; Ruby uses composition and delegation
- Java throws exceptions; Ruby collects errors
- Java uses visitor pattern extensively; Ruby uses command pattern
- Java synchronous; Ruby can be async (future enhancement)

#### 1.2 Type Validation Algorithm

**Jing Pattern:**
```java
public class TypeValidator {
  public void validateSimpleType(Element element, SimpleType type) {
    String value = getTextContent(element);

    // Validate against base type
    if (!isValidForBaseType(value, type.getBaseType())) {
      reportError("invalid value for type");
    }

    // Validate facets
    for (Facet facet : type.getFacets()) {
      if (!facet.validate(value)) {
        reportError("facet violation: " + facet.getName());
      }
    }
  }

  public void validateComplexType(Element element, ComplexType type) {
    // Validate attributes
    validateAttributes(element, type.getAttributeUses());

    // Validate content model
    if (type.hasComplexContent()) {
      validateComplexContent(element, type.getContentType());
    } else if (type.hasSimpleContent()) {
      validateSimpleContent(element, type.getSimpleContentType());
    }
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::Rules
  class TypeValidationRule < ValidationRule
    def validate(xml_element, schema_element, collector)
      type_def = resolve_element_type(schema_element)
      return unless type_def

      case type_def
      when Lutaml::Xsd::SimpleType
        validate_simple_type_content(xml_element, type_def, collector)
      when Lutaml::Xsd::ComplexType
        validate_complex_type_content(xml_element, type_def, collector)
      end
    end

    private

    def validate_simple_type_content(element, simple_type, collector)
      value = element.text_content

      # Validate base type
      base_validator = BaseTypeValidator.for(simple_type.base_type)
      unless base_validator.valid?(value)
        collector.add_error(
          InvalidValueError.new(
            element: element.qualified_name,
            value: value,
            expected_type: simple_type.base_type,
            location: element.xpath
          )
        )
        return
      end

      # Validate facets
      validate_facets(value, simple_type, element, collector)
    end

    def validate_complex_type_content(element, complex_type, collector)
      # Validate attributes
      AttributeValidationRule.new.validate(element, complex_type, collector)

      # Validate content
      if complex_type.complex_content
        validate_complex_content(element, complex_type, collector)
      elsif complex_type.simple_content
        validate_simple_content(element, complex_type, collector)
      elsif complex_type.sequence || complex_type.choice || complex_type.all
        ContentModelValidationRule.new.validate(element, complex_type, collector)
      end
    end
  end
end
```

#### 1.3 Facet Validation Algorithm

**Jing Pattern:**
```java
public interface Facet {
  boolean validate(String value);
  String getErrorMessage(String value);
}

public class PatternFacet implements Facet {
  private Pattern pattern;

  public boolean validate(String value) {
    return pattern.matcher(value).matches();
  }
}

public class LengthFacet implements Facet {
  private int length;

  public boolean validate(String value) {
    return value.length() == length;
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::Facets
  class FacetValidator
    def initialize(facet)
      @facet = facet
    end

    # @abstract
    def valid?(value)
      raise NotImplementedError
    end

    # @abstract
    def error_message(value)
      raise NotImplementedError
    end
  end

  class PatternFacetValidator < FacetValidator
    def valid?(value)
      regex = Regexp.new(@facet.value)
      value.match?(regex)
    end

    def error_message(value)
      "Value '#{value}' does not match pattern '#{@facet.value}'"
    end
  end

  class LengthFacetValidator < FacetValidator
    def valid?(value)
      value.length == @facet.value.to_i
    end

    def error_message(value)
      "Value length #{value.length} does not equal required length #{@facet.value}"
    end
  end

  # Registry for facet validators
  class FacetValidatorRegistry
    VALIDATORS = {
      Lutaml::Xsd::Pattern => PatternFacetValidator,
      Lutaml::Xsd::Length => LengthFacetValidator,
      Lutaml::Xsd::MinLength => MinLengthFacetValidator,
      Lutaml::Xsd::MaxLength => MaxLengthFacetValidator,
      Lutaml::Xsd::Enumeration => EnumerationFacetValidator,
      Lutaml::Xsd::MinInclusive => MinInclusiveFacetValidator,
      Lutaml::Xsd::MaxInclusive => MaxInclusiveFacetValidator,
      Lutaml::Xsd::MinExclusive => MinExclusiveFacetValidator,
      Lutaml::Xsd::MaxExclusive => MaxExclusiveFacetValidator,
      Lutaml::Xsd::TotalDigits => TotalDigitsFacetValidator,
      Lutaml::Xsd::FractionDigits => FractionDigitsFacetValidator,
      Lutaml::Xsd::WhiteSpace => WhiteSpaceFacetValidator
    }.freeze

    def self.validator_for(facet)
      validator_class = VALIDATORS[facet.class]
      raise UnknownFacetError, facet.class unless validator_class

      validator_class.new(facet)
    end
  end
end
```

### Phase 2: Content Model Validation

#### 2.1 Sequence Validation Algorithm

**Jing Pattern:**
```java
public class SequenceValidator {
  public void validate(Element parent, Sequence sequence) {
    List<Element> children = getChildElements(parent);
    int childIndex = 0;

    for (Particle particle : sequence.getParticles()) {
      int minOccurs = particle.getMinOccurs();
      int maxOccurs = particle.getMaxOccurs();
      int count = 0;

      // Match children against this particle
      while (childIndex < children.size() && count < maxOccurs) {
        Element child = children.get(childIndex);
        if (matches(child, particle)) {
          validate(child, particle);
          childIndex++;
          count++;
        } else {
          break;
        }
      }

      // Check occurrence constraints
      if (count < minOccurs) {
        reportError("particle " + particle + " must occur at least " + minOccurs);
      }
    }

    // Check for unexpected children
    if (childIndex < children.size()) {
      reportError("unexpected element: " + children.get(childIndex).getTagName());
    }
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::ContentModel
  class SequenceValidator
    def validate(parent_element, sequence, collector)
      children = parent_element.children
      child_index = 0

      sequence.particles.each do |particle|
        min_occurs = parse_occurs(particle.min_occurs, 1)
        max_occurs = parse_occurs(particle.max_occurs, 1)
        count = 0

        # Match children against this particle
        while child_index < children.size && count < max_occurs
          child = children[child_index]

          if particle_matches?(child, particle)
            validate_particle(child, particle, collector)
            child_index += 1
            count += 1
          else
            break
          end
        end

        # Check minimum occurrence
        if count < min_occurs
          collector.add_error(
            OccurrenceViolationError.new(
              particle: particle_name(particle),
              expected_min: min_occurs,
              actual: count,
              location: parent_element.xpath
            )
          )
        end
      end

      # Check for unexpected children
      if child_index < children.size
        unexpected = children[child_index..-1]
        unexpected.each do |child|
          collector.add_error(
            UnexpectedElementError.new(
              element: child.qualified_name,
              location: child.xpath,
              suggestion: "Remove this element or check sequence order"
            )
          )
        end
      end
    end

    private

    def parse_occurs(value, default)
      return :unbounded if value == "unbounded"
      return default if value.nil? || value.empty?
      value.to_i
    end

    def particle_matches?(element, particle)
      case particle
      when Lutaml::Xsd::Element
        element.name == particle.name &&
          element.namespace_uri == particle.target_namespace
      when Lutaml::Xsd::Group
        group_contains_element?(particle, element)
      when Lutaml::Xsd::Choice
        choice_contains_element?(particle, element)
      else
        false
      end
    end
  end
end
```

#### 2.2 Choice Validation Algorithm

**Jing Pattern:**
```java
public class ChoiceValidator {
  public void validate(Element parent, Choice choice) {
    List<Element> children = getChildElements(parent);
    boolean matched = false;

    for (Particle particle : choice.getParticles()) {
      if (matches(children, particle)) {
        validateParticle(children, particle);
        matched = true;
        break;
      }
    }

    if (!matched && choice.getMinOccurs() > 0) {
      reportError("one of " + getParticleNames(choice) + " required");
    }
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::ContentModel
  class ChoiceValidator
    def validate(parent_element, choice, collector)
      children = parent_element.children
      matched_particle = nil

      # Find which particle matches
      choice.particles.each do |particle|
        if children.any? { |child| particle_matches?(child, particle) }
          matched_particle = particle
          break
        end
      end

      min_occurs = parse_occurs(choice.min_occurs, 1)

      if matched_particle
        # Validate the matched particle
        children.each do |child|
          if particle_matches?(child, matched_particle)
            validate_particle(child, matched_particle, collector)
          end
        end
      elsif min_occurs > 0
        # Choice is required but not satisfied
        collector.add_error(
          ChoiceNotSatisfiedError.new(
            choices: choice.particles.map { |p| particle_name(p) },
            location: parent_element.xpath,
            suggestion: "Add one of: #{choice.particles.map { |p| particle_name(p) }.join(', ')}"
          )
        )
      end

      # Check for ambiguity (multiple choices matched)
      matched_count = choice.particles.count do |particle|
        children.any? { |child| particle_matches?(child, particle) }
      end

      if matched_count > 1
        collector.add_error(
          ChoiceAmbiguousError.new(
            location: parent_element.xpath,
            suggestion: "Only one choice should be present"
          )
        )
      end
    end
  end
end
```

### Phase 3: Identity Constraints

#### 3.1 Key/Keyref/Unique Validation

**Jing Pattern:**
```java
public class IdentityConstraintValidator {
  private Map<String, Set<String>> keyValues = new HashMap<>();

  public void validateKey(Element context, Key key) {
    // Select target elements using XPath
    List<Element> targets = evaluateSelector(context, key.getSelector());

    Set<String> values = new HashSet<>();
    for (Element target : targets) {
      // Extract key value using XPath
      String value = evaluateField(target, key.getFields());

      if (value == null) {
        reportError("key field is missing");
        continue;
      }

      if (!values.add(value)) {
        reportError("duplicate key value: " + value);
      }
    }

    // Store for keyref validation
    keyValues.put(key.getName(), values);
  }

  public void validateKeyref(Element context, Keyref keyref) {
    List<Element> targets = evaluateSelector(context, keyref.getSelector());
    Set<String> referenceValues = keyValues.get(keyref.getRefer());

    for (Element target : targets) {
      String value = evaluateField(target, keyref.getFields());

      if (!referenceValues.contains(value)) {
        reportError("keyref value '" + value + "' not found in key");
      }
    }
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::Rules
  class IdentityConstraintRule < ValidationRule
    def initialize(options = {})
      super
      @key_values = {}
    end

    def validate(xml_document, schema, collector)
      # First pass: collect all key values
      schema.all_keys.each do |key|
        validate_key(xml_document, key, collector)
      end

      # Second pass: validate unique constraints
      schema.all_unique_constraints.each do |unique|
        validate_unique(xml_document, unique, collector)
      end

      # Third pass: validate keyref constraints
      schema.all_keyrefs.each do |keyref|
        validate_keyref(xml_document, keyref, collector)
      end
    end

    private

    def validate_key(document, key, collector)
      # Evaluate selector XPath
      context_elements = evaluate_selector(document, key.selector)

      key_name = qualified_name(key)
      @key_values[key_name] = Set.new

      context_elements.each do |context|
        # Evaluate field XPath
        value = evaluate_fields(context, key.field)

        if value.nil?
          collector.add_error(
            KeyFieldMissingError.new(
              key: key_name,
              location: context.xpath
            )
          )
          next
        end

        # Check for duplicate
        unless @key_values[key_name].add?(value)
          collector.add_error(
            DuplicateKeyError.new(
              key: key_name,
              value: value,
              location: context.xpath
            )
          )
        end
      end
    end

    def validate_unique(document, unique, collector)
      context_elements = evaluate_selector(document, unique.selector)
      seen_values = Set.new

      context_elements.each do |context|
        value = evaluate_fields(context, unique.field)
        next if value.nil? # unique allows null

        unless seen_values.add?(value)
          collector.add_error(
            UniqueViolationError.new(
              constraint: qualified_name(unique),
              value: value,
              location: context.xpath
            )
          )
        end
      end
    end

    def validate_keyref(document, keyref, collector)
      context_elements = evaluate_selector(document, keyref.selector)
      referenced_key = qualified_name_from_qname(keyref.refer)
      reference_values = @key_values[referenced_key]

      unless reference_values
        collector.add_error(
          KeyNotFoundError.new(
            keyref: qualified_name(keyref),
            refer: referenced_key
          )
        )
        return
      end

      context_elements.each do |context|
        value = evaluate_fields(context, keyref.field)
        next if value.nil? # keyref can be null

        unless reference_values.include?(value)
          collector.add_error(
            KeyrefViolationError.new(
              keyref: qualified_name(keyref),
              value: value,
              referred_key: referenced_key,
              location: context.xpath,
              suggestion: "Available values: #{reference_values.to_a.join(', ')}"
            )
          )
        end
      end
    end

    def evaluate_selector(document, selector)
      # Use Moxml XPath evaluation
      xpath = selector.xpath
      document.xpath(xpath)
    end

    def evaluate_fields(context, fields)
      # Concatenate all field values
      fields.map do |field|
        xpath = field.xpath
        context.xpath(xpath).first&.text
      end.compact.join('|')
    end
  end
end
```

## Base Type Validation

### Built-in Type Validators

**Java Pattern:**
```java
public abstract class BaseTypeValidator {
  public abstract boolean isValid(String value);

  public static BaseTypeValidator getValidator(String typeName) {
    switch (typeName) {
      case "string": return new StringValidator();
      case "integer": return new IntegerValidator();
      case "decimal": return new DecimalValidator();
      // ... etc
    }
  }
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation::BaseTypes
  class BaseTypeValidator
    # @abstract
    def valid?(value)
      raise NotImplementedError
    end

    def self.for(type_name)
      VALIDATORS[type_name] || StringValidator.new
    end

    VALIDATORS = {
      'string' => StringValidator.new,
      'boolean' => BooleanValidator.new,
      'decimal' => DecimalValidator.new,
      'float' => FloatValidator.new,
      'double' => DoubleValidator.new,
      'duration' => DurationValidator.new,
      'dateTime' => DateTimeValidator.new,
      'time' => TimeValidator.new,
      'date' => DateValidator.new,
      'gYearMonth' => GYearMonthValidator.new,
      'gYear' => GYearValidator.new,
      'gMonthDay' => GMonthDayValidator.new,
      'gDay' => GDayValidator.new,
      'gMonth' => GMonthValidator.new,
      'hexBinary' => HexBinaryValidator.new,
      'base64Binary' => Base64BinaryValidator.new,
      'anyURI' => AnyURIValidator.new,
      'QName' => QNameValidator.new,
      'NOTATION' => NotationValidator.new,
      'normalizedString' => NormalizedStringValidator.new,
      'token' => TokenValidator.new,
      'language' => LanguageValidator.new,
      'NMTOKEN' => NMTokenValidator.new,
      'NMTOKENS' => NMTokensValidator.new,
      'Name' => NameValidator.new,
      'NCName' => NCNameValidator.new,
      'ID' => IDValidator.new,
      'IDREF' => IDREFValidator.new,
      'IDREFS' => IDREFSValidator.new,
      'ENTITY' => EntityValidator.new,
      'ENTITIES' => EntitiesValidator.new,
      'integer' => IntegerValidator.new,
      'nonPositiveInteger' => NonPositiveIntegerValidator.new,
      'negativeInteger' => NegativeIntegerValidator.new,
      'long' => LongValidator.new,
      'int' => IntValidator.new,
      'short' => ShortValidator.new,
      'byte' => ByteValidator.new,
      'nonNegativeInteger' => NonNegativeIntegerValidator.new,
      'unsignedLong' => UnsignedLongValidator.new,
      'unsignedInt' => UnsignedIntValidator.new,
      'unsignedShort' => UnsignedShortValidator.new,
      'unsignedByte' => UnsignedByteValidator.new,
      'positiveInteger' => PositiveIntegerValidator.new
    }.freeze
  end

  class StringValidator < BaseTypeValidator
    def valid?(value)
      value.is_a?(String)
    end
  end

  class IntegerValidator < BaseTypeValidator
    def valid?(value)
      Integer(value)
      true
    rescue ArgumentError, TypeError
      false
    end
  end

  class DateTimeValidator < BaseTypeValidator
    ISO8601_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$/

    def valid?(value)
      return false unless value.match?(ISO8601_PATTERN)

      DateTime.iso8601(value)
      true
    rescue ArgumentError
      false
    end
  end

  # ... other validators
end
```

## Error Handling Patterns

### Jing Error Handler

**Java:**
```java
public interface ErrorHandler {
  void error(SAXParseException exception);
  void warning(SAXParseException exception);
  void fatalError(SAXParseException exception);
}
```

**Ruby Port:**
```ruby
module Lutaml::Xsd::Validation
  class ErrorCollector
    def initialize
      @errors = []
      @warnings = []
      @infos = []
    end

    attr_reader :errors, :warnings, :infos

    def add_error(error)
      @errors << error
    end

    def add_warning(warning)
      @warnings << warning
    end

    def add_info(info)
      @infos << info
    end

    def has_errors?
      @errors.any?
    end

    def to_result
      ValidationResult.new(
        valid: !has_errors?,
        errors: @errors,
        warnings: @warnings,
        infos: @infos
      )
    end
  end
end
```

## Testing Strategy for Ported Algorithms

### Comparative Testing

Create test cases that verify Ruby implementation matches Jing behavior:

```ruby
# spec/validation/jing_compatibility_spec.rb
RSpec.describe 'Jing Compatibility' do
  # Test against same fixtures Jing uses
  let(:xsd_content) { File.read('spec/fixtures/jing/schema.xsd') }
  let(:valid_xml) { File.read('spec/fixtures/jing/valid.xml') }
  let(:invalid_xml) { File.read('spec/fixtures/jing/invalid.xml') }

  describe 'element validation' do
    it 'matches Jing behavior for valid documents' do
      # Run Jing validator (via system call)
      jing_result = run_jing_validator(xsd_content, valid_xml)

      # Run our validator
      validator = Lutaml::Xsd::Validator.new(schema_content: xsd_content)
      our_result = validator.validate(valid_xml)

      # Compare results
      expect(our_result.valid?).to eq(jing_result.valid?)
    end

    it 'matches Jing error codes for invalid documents' do
      jing_result = run_jing_validator(xsd_content, invalid_xml)
      our_result = Lutaml::Xsd::Validator.new(schema_content: xsd_content)
                                         .validate(invalid_xml)

      # Map error codes
      our_error_codes = our_result.errors.map(&:code).sort
      jing_error_codes = map_jing_error_codes(jing_result.errors).sort

      expect(our_error_codes).to eq(jing_error_codes)
    end
  end
end
```

## Implementation Checklist

### Week 1-2: Foundation
- [ ] Set up Moxml integration
- [ ] Create XmlNavigator wrapper
- [ ] Implement base ValidationRule
- [ ] Port element existence checking
- [ ] Port namespace validation
- [ ] Write tests comparing to Jing

### Week 3-4: Type System
- [ ] Port base type validators (all XSD built-in types)
- [ ] Port simple type validation
- [ ] Port complex type validation
- [ ] Port facet validators (pattern, length, etc.)
- [ ] Test against Jing type validation

### Week 5-6: Content Models
- [ ] Port sequence validation algorithm
- [ ] Port choice validation algorithm
- [ ] Port all group validation algorithm
- [ ] Port occurrence checking
- [ ] Test against Jing content model validation

### Week 7-8: Advanced Features
- [ ] Port identity constraint validation (key/keyref/unique)
- [ ] Port substitution group handling
- [ ] Port abstract type checking
- [ ] Port wildcard (any) handling
- [ ] Comprehensive Jing compatibility testing

## Performance Considerations

### Jing Optimizations to Port

1. **Schema Compilation:**
   ```ruby
   # Cache compiled schemas
   class CompiledSchema
     def initialize(schema)
       @schema = schema
       @type_cache = build_type_cache(schema)
       @element_cache = build_element_cache(schema)
     end
   end
   ```

2. **XPath Evaluation:**
   ```ruby
   # Cache compiled XPath expressions
   class XPathCache
     def evaluate(expression, context)
       compiled = @cache[expression] ||= compile(expression)
       compiled.evaluate(context)
     end
   end
   ```

3. **Type Hierarchy:**
   ```ruby
   # Pre-compute type derivation chains
   class TypeHierarchy
     def derives_from?(derived, base)
       @derivation_cache[[derived, base]] ||= compute_derivation(derived, base)
     end
   end
   ```

## Documentation Requirements

Each ported algorithm must include:

1. **Algorithm Description:** High-level explanation
2. **Jing Reference:** Link to corresponding Jing source
3. **Differences:** Any deviations from Jing behavior
4. **Examples:** Code examples showing usage
5. **Tests:** RSpec tests with Jing comparison

## Summary

This porting strategy ensures:
- **Feature Parity:** All Jing XSD validation capabilities
- **Clean Architecture:** Ruby idioms, not Java translation
- **Testability:** Comparative testing against Jing
- **Maintainability:** Well-documented, modular code
- **Performance:** Optimizations ported from Jing

The phased approach allows iterative development with continuous validation against Jing reference implementation.