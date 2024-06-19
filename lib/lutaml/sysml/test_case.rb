module Lutaml::SysMl

class TestCase < Lutaml::Uml::TopElement
	attr_accessor :base_behavior, :verifies
	
  def name
		if base_behavior != nil and base_behavior.name != nil
 			return base_behavior.name
		end
		return nil
	end
  
	def full_name
		if base_behavior != nil and base_behavior.name != nil
 			return base_behavior.full_name
		end
		return nil
	end

end

end