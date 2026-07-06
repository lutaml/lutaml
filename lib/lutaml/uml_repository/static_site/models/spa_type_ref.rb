# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        # A precomputed, deterministic reference from an attribute's type to the
        # class it resolves to, so the SPA can navigate/link without guessing by
        # name on the client. Absent (nil) for primitives and unresolved types,
        # which have no class to point at.
        class SpaTypeRef < SpaBase
          attribute :class_id, :string
          attribute :qualified_name, :string
          attribute :ambiguous, :boolean, default: false

          json do
            map "classId", to: :class_id
            map "qualifiedName", to: :qualified_name
            map "ambiguous", to: :ambiguous, render_default: true
          end

          # Build from a TypeResolver::Result. Returns nil unless the type
          # resolved to an actual classifier; `ambiguous` records that the
          # simple name matched more than one class (the first was chosen).
          def self.from_resolution(resolution, id_generator)
            return nil unless resolution&.resolved?
            return nil if resolution.classifier.nil?

            new(
              class_id: id_generator.class_id(resolution.classifier),
              qualified_name: resolution.qualified_name,
              ambiguous: resolution.ambiguous?,
            )
          end
        end
      end
    end
  end
end
