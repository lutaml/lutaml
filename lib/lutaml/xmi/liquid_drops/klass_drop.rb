# frozen_string_literal: true

module Lutaml
  module XMI
    class KlassDrop < Liquid::Drop
      def initialize(model, guidance = nil) # rubocop:disable Lint/MissingSuper
        @model = model
        @guidance = guidance

        if guidance && guidance["classes"].map do |c|
          c["name"]
        end.include?(@model[:name])
          @klass_guidance = guidance["classes"].find do |klass|
            klass["name"] == @model[:name]
          end
        end
      end

      def xmi_id
        @model[:xmi_id]
      end

      def name
        @model[:name]
      end

      def package
        ::Lutaml::XMI::PackageDrop.new(@model[:package], @guidance)
      end

      def type
        @model[:type]
      end

      def attributes
        @model[:attributes]&.map do |attribute|
          ::Lutaml::XMI::AttributeDrop.new(attribute)
        end
      end

      def associations
        @model[:associations]&.map do |association|
          ::Lutaml::XMI::AssociationDrop.new(association)
        end
      end

      def operations
        @model[:operations]&.map do |operation|
          ::Lutaml::XMI::OperationDrop.new(operation)
        end
      end

      def constraints
        @model[:constraints]&.map do |constraint|
          ::Lutaml::XMI::ConstraintDrop.new(constraint)
        end
      end

      def generalization
        return {} if @model[:generalization].nil?

        ::Lutaml::XMI::GeneralizationDrop.new(@model[:generalization],
                                              @klass_guidance)
      end

      def is_abstract
        @model[:is_abstract]
      end

      def definition
        @model[:definition]
      end

      def stereotype
        @model[:stereotype]
      end
    end
  end
end
