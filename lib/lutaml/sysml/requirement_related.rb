module Lutaml
  module SysMl
    class RequirementRelated < Lutaml::Uml::TopElement
      attr_accessor :base_named_element, :satisfies, :refines
    end
  end
end
