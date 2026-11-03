# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaProperty < Base
        attribute :name, :string
        attribute :title, :string
        attribute :description, :string
        attribute :type, :string
        attribute :format, :string
        attribute :required, :boolean
        attribute :default, :string
        attribute :pattern, :string
        attribute :enum, :string, collection: true
        attribute :enum_descriptions, :hash
        attribute :ref, :string
        # `$ref` sibling semantics differ by dialect (draft-04 ignores
        # them, 2019-09+ applies them); exactly one is set when the
        # source carries siblings beside the `$ref`.
        attribute :ref_siblings_ignored, :boolean
        attribute :ref_siblings_apply, :boolean
        # whether `format` asserts in the schema's dialect (draft-04/06/07)
        # or only annotates (2019-09+)
        attribute :format_assertion, :boolean
        attribute :min_length, :integer
        attribute :max_length, :integer
        attribute :minimum, :float
        attribute :maximum, :float
        attribute :items_type, :string
        attribute :items_ref, :string
        attribute :deprecated, :boolean
        attribute :read_only, :boolean
        attribute :write_only, :boolean
        attribute :examples, :string, collection: true
        attribute :min_items, :integer
        attribute :max_items, :integer
        attribute :unique_items, :boolean
        attribute :multiple_of, :float
        attribute :const_value, :string
        attribute :exclusive_minimum, :float
        attribute :exclusive_maximum, :float
        attribute :additional_properties, :boolean
        attribute :additional_properties_ref, :string
        attribute :additional_properties_type, :string
        attribute :content_type, :string
        attribute :content_encoding, :string
        attribute :composition_source, :string

        # Object-level constraints for nested object properties
        attribute :min_properties, :integer
        attribute :max_properties, :integer

        # Nested structure for object-typed properties
        attribute :properties, SpaProperty, collection: true,
                                            initialize_empty: true
        attribute :discriminator, :hash
        attribute :required_fields, :string, collection: true,
                                             initialize_empty: true
        attribute :definitions, SpaDefinition, collection: true,
                                               initialize_empty: true

        # Array items detail (when items is an object schema)
        attribute :items_properties, SpaProperty, collection: true,
                                                  initialize_empty: true
        attribute :items_required, :string, collection: true,
                                            initialize_empty: true
        attribute :items_enum, :string, collection: true
        attribute :items_format, :string
        attribute :items_tuple, :string, collection: true
        attribute :items_tail, :string
        attribute :items_closed, :boolean

        # Contains (array must contain at least one item matching schema)
        attribute :contains_type, :string
        attribute :contains_ref, :string

        # patternProperties
        attribute :pattern_properties, :hash

        # Composition variants
        attribute :one_of_variants, SpaProperty, collection: true,
                                                 initialize_empty: true
        attribute :any_of_variants, SpaProperty, collection: true,
                                                 initialize_empty: true

        # not constraint
        attribute :not_type, :string

        # Hyper-schema links
        attribute :links, SpaLink, collection: true,
                                   initialize_empty: true

        json do
          map "name", to: :name
          map "title", to: :title
          map "description", to: :description
          map "type", to: :type
          map "format", to: :format
          map "required", to: :required
          map "default", to: :default
          map "pattern", to: :pattern
          map "enum", to: :enum
          map "enumDescriptions", to: :enum_descriptions
          map "$ref", to: :ref
          map "refSiblingsIgnored", to: :ref_siblings_ignored
          map "refSiblingsApply", to: :ref_siblings_apply
          map "formatAssertion", to: :format_assertion
          map "minLength", to: :min_length
          map "maxLength", to: :max_length
          map "minimum", to: :minimum
          map "maximum", to: :maximum
          map "itemsType", to: :items_type
          map "itemsRef", to: :items_ref
          map "deprecated", to: :deprecated
          map "readOnly", to: :read_only
          map "writeOnly", to: :write_only
          map "examples", to: :examples
          map "minItems", to: :min_items
          map "maxItems", to: :max_items
          map "uniqueItems", to: :unique_items
          map "multipleOf", to: :multiple_of
          map "const", to: :const_value
          map "exclusiveMinimum", to: :exclusive_minimum
          map "exclusiveMaximum", to: :exclusive_maximum
          map "additionalProperties", to: :additional_properties
          map "additionalPropertiesRef", to: :additional_properties_ref
          map "additionalPropertiesType", to: :additional_properties_type
          map "contentMediaType", to: :content_type
          map "contentEncoding", to: :content_encoding
          map "compositionSource", to: :composition_source
          map "minProperties", to: :min_properties
          map "maxProperties", to: :max_properties
          map "properties", to: :properties
          map "discriminator", to: :discriminator
          map "requiredFields", to: :required_fields
          map "definitions", to: :definitions
          map "itemsProperties", to: :items_properties
          map "itemsRequired", to: :items_required
          map "itemsEnum", to: :items_enum
          map "itemsFormat", to: :items_format
          map "itemsTuple", to: :items_tuple
          map "itemsTail", to: :items_tail
          map "itemsClosed", to: :items_closed
          map "containsType", to: :contains_type
          map "containsRef", to: :contains_ref
          map "patternProperties", to: :pattern_properties
          map "oneOfVariants", to: :one_of_variants
          map "anyOfVariants", to: :any_of_variants
          map "notType", to: :not_type
          map "links", to: :links
        end
      end
    end
  end
end
