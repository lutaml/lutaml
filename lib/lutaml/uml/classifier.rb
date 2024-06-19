# frozen_string_literal: true

require "lutaml/uml/top_element"

module Lutaml
  module Uml
    class Classifier < TopElement
      attr_accessor :generalization
    end
  end
end
