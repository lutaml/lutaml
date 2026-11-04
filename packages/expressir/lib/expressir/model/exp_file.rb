# frozen_string_literal: true

module Expressir
  module Model
    # Represents a single EXPRESS file containing schemas and preamble remarks.
    # This class preserves file-level information including:
    # - File path for reference
    # - Preamble remarks (comments at the top of the file before any schema)
    # - Schemas defined in this file
    #
    # A Repository contains multiple ExpFile instances when parsing multiple files,
    # or a single ExpFile when parsing a single file.
    class ExpFile < ModelElement
      include HasId
      include ScopeContainer

      collection_attributes :schemas

      attribute :path, :string
      attribute :schemas, Declarations::Schema, collection: true,
                                                initialize_empty: true
      attribute :_class, :string, default: -> { self.class.name }

      key_value do
        map "_class", to: :_class, render_default: true
        map "path", to: :path
        map "schemas", to: :schemas
      end

      # Returns the file path as the identifier
      # @return [String, nil] The file path or nil
      def id
        path
      end

      # @return [Array<Declaration>]
      def children
        schemas
      end
    end
  end
end
