# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaDefinition < Base
        attribute :name, :string
        attribute :title, :string
        attribute :description, :string
        attribute :type, :string
        attribute :format, :string
        attribute :enum, :string, collection: true
        attribute :enum_descriptions, :hash
        attribute :const_value, :string
        attribute :pattern, :string
        attribute :default, :string
        attribute :min_length, :integer
        attribute :max_length, :integer
        attribute :minimum, :float
        attribute :maximum, :float
        attribute :exclusive_minimum, :float
        attribute :exclusive_maximum, :float
        attribute :multiple_of, :float
        attribute :content_type, :string
        attribute :content_encoding, :string
        attribute :properties, SpaProperty, collection: true,
                                            initialize_empty: true
        attribute :discriminator, :hash
        attribute :required, :string, collection: true
        attribute :examples, :string, collection: true
        attribute :min_properties, :integer
        attribute :max_properties, :integer
        attribute :additional_properties, :boolean
        attribute :additional_properties_ref, :string
        attribute :additional_properties_type, :string
        attribute :has_all_of, :boolean
        attribute :has_any_of, :boolean
        attribute :has_one_of, :boolean
        attribute :composition_variants, :string, collection: true

        # Array items detail (when items is an object schema)
        attribute :items_type, :string
        attribute :items_ref, :string
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

        # not constraint
        attribute :not_type, :string

        # oneOf/anyOf variant schemas
        attribute :one_of_variants, SpaProperty, collection: true,
                                                 initialize_empty: true
        attribute :any_of_variants, SpaProperty, collection: true,
                                                 initialize_empty: true

        # Hyper-schema links
        attribute :links, SpaLink, collection: true,
                                   initialize_empty: true

        json do
          map "name", to: :name
          map "title", to: :title
          map "description", to: :description
          map "type", to: :type
          map "format", to: :format
          map "enum", to: :enum
          map "enumDescriptions", to: :enum_descriptions
          map "const", to: :const_value
          map "pattern", to: :pattern
          map "default", to: :default
          map "minLength", to: :min_length
          map "maxLength", to: :max_length
          map "minimum", to: :minimum
          map "maximum", to: :maximum
          map "exclusiveMinimum", to: :exclusive_minimum
          map "exclusiveMaximum", to: :exclusive_maximum
          map "multipleOf", to: :multiple_of
          map "contentMediaType", to: :content_type
          map "contentEncoding", to: :content_encoding
          map "properties", to: :properties
          map "discriminator", to: :discriminator
          map "required", to: :required
          map "examples", to: :examples
          map "minProperties", to: :min_properties
          map "maxProperties", to: :max_properties
          map "additionalProperties", to: :additional_properties
          map "additionalPropertiesRef", to: :additional_properties_ref
          map "additionalPropertiesType", to: :additional_properties_type
          map "hasAllOf", to: :has_all_of
          map "hasAnyOf", to: :has_any_of
          map "hasOneOf", to: :has_one_of
          map "compositionVariants", to: :composition_variants
          map "itemsType", to: :items_type
          map "itemsRef", to: :items_ref
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
          map "notType", to: :not_type
          map "oneOfVariants", to: :one_of_variants
          map "anyOfVariants", to: :any_of_variants
          map "links", to: :links
        end
      end
    end
  end
end
