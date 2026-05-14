# frozen_string_literal: true

module Lutaml
  module Ea
    module Diagram
      module ElementRenderers
        autoload :BaseRenderer,
                 "lutaml/ea/diagram/element_renderers/base_renderer"
        autoload :ClassRenderer,
                 "lutaml/ea/diagram/element_renderers/class_renderer"
        autoload :PackageRenderer,
                 "lutaml/ea/diagram/element_renderers/package_renderer"
        autoload :ConnectorRenderer,
                 "lutaml/ea/diagram/element_renderers/connector_renderer"
      end
    end
  end
end
