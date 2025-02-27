module Lutaml
  module SysMl
    class NestedConnectorEnd < Lutaml::Uml::ConnectorEnd
      attr_accessor :base_connectorend, :property_path

      def initialize
        @property_path = []
      end
    end
  end
end
