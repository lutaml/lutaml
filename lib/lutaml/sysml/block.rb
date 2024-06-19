module Lutaml::SysMl

class Block < Lutaml::Uml::Class
	attr_accessor :base_class
	def initialize
		@xmi_id = nil
		@nested_classifier = []
		@stereotype = []
		@namespace = nil
	end
	
  def name
		if base_class != nil and base_class.name != nil
 			return base_class.name
		end
		return nil
	end
  
	def full_name
		if base_class != nil and base_class.name != nil
 			return base_class.full_name
		end
		return nil
	end
end

end