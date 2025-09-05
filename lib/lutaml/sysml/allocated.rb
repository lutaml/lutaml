module Lutaml
  module Sysml
    class Allocated < Lutaml::Uml::TopElement
      attr_accessor :base_named_element, :allocated_from, :allocated_to
    end
  end
end
