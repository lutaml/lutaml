# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates attribute references and structure
      class AttributeValidator < BaseValidator
        def validate
          validate_parent_object_references
          validate_type_references
        end

        private

        def validate_parent_object_references
          attributes.each do |attr|
            unless reference_exists?("t_object", "ea_object_id",
                                     attr.ea_object_id)
              parent = database&.objects&.all&.find do |o|
                o.ea_object_id == attr.ea_object_id
              end
              attr_location = if parent
                                "#{resolve_class_path(parent.ea_object_id,
                                                      parent.name)}::#{attr.name}"
                              else
                                "Unknown::#{attr.name} (attribute_id: #{attr.id})"
                              end
              result.add_error(
                category: :missing_reference,
                entity_type: :attribute,
                entity_id: attr.id.to_s,
                entity_name: attr.name,
                field: "ea_object_id",
                reference: attr.ea_object_id.to_s,
                message: "Parent object #{attr.ea_object_id} does not exist",
                location: attr_location,
              )
            end
          end
        end

        def validate_type_references
          attributes.each do |attr|
            next unless attr.classifier && !attr.classifier.empty?

            # Classifier can be either an object ID or a primitive type name
            next if primitive_type?(attr.classifier)
            next if classifier_exists?(attr.classifier)

            parent = database&.objects&.all&.find do |o|
              o.ea_object_id == attr.ea_object_id
            end
            attr_location = if parent
                              "#{resolve_class_path(parent.ea_object_id,
                                                    parent.name)}::#{attr.name}"
                            else
                              "Unknown::#{attr.name} (attribute_id: #{attr.id})"
                            end
            result.add_warning(
              category: :missing_reference,
              entity_type: :attribute,
              entity_id: attr.id.to_s,
              entity_name: "#{parent&.name}.#{attr.name}",
              field: "classifier",
              reference: attr.classifier,
              message: "Classifier '#{attr.classifier}' not found",
              location: attr_location,
            )
          end
        end

        def attributes
          @attributes ||= context[:attributes] || []
        end

        def classifier_exists?(classifier_id)
          return false unless database

          # Classifier field contains object_id, not name
          database.objects.all.any? do |o|
            o.ea_object_id.to_s == classifier_id.to_s
          end
        end

        def primitive_type?(type_name)
          # Common primitive and built-in types
          primitives = %w[
            Integer String Boolean Float Double Long Short Byte Char
            Date Time DateTime Decimal
            int string bool float double long short byte char
            void Object Any
          ]
          primitives.include?(type_name)
        end
      end
    end
  end
end
