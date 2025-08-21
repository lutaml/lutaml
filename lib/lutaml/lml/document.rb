# frozen_string_literal: true

module Lutaml
  module Uml
    class Document < Uml::Document
      attr_accessor :instances, :requires
    end
  end
end
