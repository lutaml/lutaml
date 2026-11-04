# frozen_string_literal: true

module Expressir
  module Eengine
    # Represents an Eengine MIM comparison XML report
    class MimCompareReport < Lutaml::Model::Serializable
      attribute :modifications, ChangesSection
      attribute :additions, ChangesSection
      attribute :deletions, ChangesSection

      xml do
        element "mim.changes"
        map_element "mim.modifications", to: :modifications
        map_element "mim.additions", to: :additions
        map_element "mim.deletions", to: :deletions
      end

      def mode
        "mim"
      end
    end
  end
end
