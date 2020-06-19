module Lutaml::SysMl

class NestedConnectorEnd < Lutaml::Uml::ConnectorEnd
	attr_accessor :base_connectorend, :property_path
	def initialize
		@property_path = []
	end
end


end