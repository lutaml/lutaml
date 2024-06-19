module Lutaml::Sysml

class Requirement < Lutaml::Uml::Class
	attr_accessor :id, :text, :base_class, :refined_by, :traced_to, :derived_from, :satisfied_by
	def initialize
		@xmi_id = nil
		@id = nil
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
##	def name
## 		if base_class != nil and base_class.name != nil
## 			base_class.name
##		else
##			nil
## 		end
## 	end
## 	def full_name
## 		get_base_class_full_name ( self )
##	end
end