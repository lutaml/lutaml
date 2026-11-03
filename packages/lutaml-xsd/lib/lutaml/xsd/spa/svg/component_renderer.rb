# frozen_string_literal: true

require_relative "utils/svg_builder"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Abstract base class for component renderers
        # Subclasses must implement #render method
        class ComponentRenderer
          attr_reader :config, :schema_name

          def initialize(config, schema_name)
            @config = config
            @schema_name = schema_name
          end

          # Renders a component at the given position
          # @param component_data [Hash] The component data to render
          # @param box [Geometry::Box] The bounding box for the component
          # @return [String] SVG markup
          def render(component_data, box)
            raise NotImplementedError, "#{self.class} must implement #render"
          end

          protected

          # Creates a basic box with fill and stroke
          def create_box(box, fill, options = {})
            attributes = {
              fill: fill,
              stroke: options[:stroke] || config.colors.ui.border,
              "stroke-width" => options[:stroke_width] || 2,
              rx: options[:corner_radius] || config.dimensions.box_corner_radius,
            }

            if options[:filter]
              attributes[:filter] =
                "url(##{options[:filter]})"
            end

            Utils::SvgBuilder.rect(box.x, box.y, box.width, box.height,
                                   attributes)
          end

          # Creates text centered in a box
          def create_centered_text(box, text, options = {})
            Utils::SvgBuilder.text(
              box.center.x,
              box.y + (options[:offset_y] || config.dimensions.text_offset_y),
              text,
              {
                fill: options[:fill] || "white",
                "font-size" => options[:font_size] || config.dimensions.text_font_size,
                "font-weight" => options[:font_weight] || "bold",
                "text-anchor" => "middle",
              },
            )
          end

          # Creates a clickable link wrapper
          def create_link(href, &)
            Utils::SvgBuilder.element("a", { href: href }, &)
          end

          # Generates a semantic URI for linking
          def semantic_uri(component_type, name)
            slug = slugify(name)
            "#/schemas/#{schema_name}/#{component_type}/#{slug}"
          end

          # CamelCase-aware slugification
          #
          # NOTE: The regex pattern /([A-Z]+)([A-Z][a-z])/ is marked as potentially
          # polynomial by CodeQL. However, this is only triggered by unusually long
          # strings of consecutive uppercase letters. Schema type names are typically
          # short (e.g., "XMLSchema", "PersonType") and not user-controlled, so the
          # actual risk is negligible. Using possessive quantifiers (e.g., /(?>[A-Z]++)/)
          # was evaluated but breaks the intended acronym splitting (e.g., "XMLSchema"
          # → "xml-schema" instead of "xmlschema").
          def slugify(name)
            return "" unless name

            name.gsub(/([a-z])([A-Z])/, '\1-\2')
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
              .downcase
              .gsub(/[^a-z0-9]+/, "-")
              .gsub(/^-|-$/, "")
          end
        end
      end
    end
  end
end
