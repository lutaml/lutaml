# frozen_string_literal: true

module Lutaml
  module XMI
    class AttributeDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
        @model = model
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @xmi_cache = options[:xmi_cache]

        uml_type = @model.uml_type
        @uml_type_idref = uml_type.idref if uml_type
      end

      def id
        @model.id
      end

      def name
        @model.name
      end

      def type
        lookup_entity_name(@uml_type_idref) || @uml_type_idref
      end

      def xmi_id
        @uml_type_idref
      end

      def is_derived # rubocop:disable Naming/PredicateName
        @model.is_derived
      end

      def cardinality
        ::Lutaml::XMI::CardinalityDrop.new(@model)
      end

      def definition
        definition = lookup_attribute_documentation(@model.id)

        if @options[:with_assoc] && @model.association
          definition = loopup_assoc_def(@model.association)
        end

        definition
      end

      def association
        if @options[:with_assoc] && @model.association
          @model.association
        end
      end

      def type_ns
        if @options[:with_assoc] && @model.association
          get_ns_by_xmi_id(xmi_id)
        end
      end
    end
  end
end
