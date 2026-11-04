# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for visual effects configuration
          class Effects
            def initialize(effects_hash)
              @effects = effects_hash
              @shadow = ShadowEffect.new(@effects["shadow"] || {})
              @gradient = GradientEffect.new(@effects["gradient"] || {})
            end

            def shadow_enabled?
              @shadow.enabled?
            end

            def shadow_blur
              @shadow.blur
            end

            def shadow_offset_x
              @shadow.offset_x
            end

            def shadow_offset_y
              @shadow.offset_y
            end

            def shadow_opacity
              @shadow.opacity
            end

            def gradient_enabled?
              @gradient.enabled?
            end

            def gradient_direction
              @gradient.direction
            end
          end

          # Shadow effect value object
          class ShadowEffect
            attr_reader :blur, :offset_x, :offset_y, :opacity

            def initialize(shadow_hash)
              @enabled = shadow_hash["enabled"].nil? || shadow_hash["enabled"]
              @blur = shadow_hash["blur"] || 2
              @offset_x = shadow_hash["offset_x"] || 2
              @offset_y = shadow_hash["offset_y"] || 2
              @opacity = shadow_hash["opacity"] || 0.3
            end

            def enabled?
              @enabled
            end
          end

          # Gradient effect value object
          class GradientEffect
            attr_reader :direction

            def initialize(gradient_hash)
              @enabled = gradient_hash["enabled"].nil? || gradient_hash["enabled"]
              @direction = gradient_hash["direction"] || "vertical"
            end

            def enabled?
              @enabled
            end
          end
        end
      end
    end
  end
end
