# frozen_string_literal: true

require "lutaml/uml/class"

module Lutaml
  module Lml
    # Class for parsing LutaML lml into Lutaml::Lml::Document
    class Class < Uml::Class
      attribute :parent_class, :string
    end
  end
end