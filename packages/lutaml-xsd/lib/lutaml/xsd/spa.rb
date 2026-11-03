# frozen_string_literal: true

# SPA (Single Page Application) generation
require_relative "spa/configuration_loader"
require_relative "spa/generator"
require_relative "spa/html_document_builder"
require_relative "spa/output_strategy"
require_relative "spa/schema_serializer"
require_relative "spa/spa_metadata"
require_relative "spa/xml_instance_generator"

# SVG diagram generation - MECE architecture
require_relative "spa/svg/style_configuration"
require_relative "spa/svg/config/color_scheme"
require_relative "spa/svg/config/dimensions"
require_relative "spa/svg/config/effects"
require_relative "spa/svg/config/connector_styles"
require_relative "spa/svg/config/layout_config"
require_relative "spa/svg/config/component_rules"
require_relative "spa/svg/config/indicator_rules"

# SVG geometry
require_relative "spa/svg/geometry/point"
require_relative "spa/svg/geometry/box"

# SVG utilities
require_relative "spa/svg/utils/svg_builder"

# SVG base classes
require_relative "spa/svg/component_renderer"
require_relative "spa/svg/connector_renderer"
require_relative "spa/svg/layout_engine"

# SVG connectors
require_relative "spa/svg/connectors/inheritance_connector"
require_relative "spa/svg/connectors/containment_connector"
require_relative "spa/svg/connectors/reference_connector"

# SVG layouts
require_relative "spa/svg/layouts/vertical_layout"
require_relative "spa/svg/layouts/tree_layout"

# SVG renderers
require_relative "spa/svg/renderers/type_renderer"
require_relative "spa/svg/renderers/attribute_renderer"
require_relative "spa/svg/renderers/group_renderer"

# SVG builders
require_relative "spa/svg/defs_builder"
require_relative "spa/svg/document_builder"

# SVG main coordinator
require_relative "spa/svg/diagram_generator"
require_relative "spa/svg/renderers/element_renderer"
