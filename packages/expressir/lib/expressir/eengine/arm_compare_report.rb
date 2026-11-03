# frozen_string_literal: true

module Expressir
  module Eengine
    # Represents an Eengine ARM comparison XML report
    class ArmCompareReport < Lutaml::Model::Serializable
      attribute :modifications, ChangesSection
      attribute :additions, ChangesSection
      attribute :deletions, ChangesSection

      xml do
        element "arm.changes"
        map_element "arm.modifications", to: :modifications
        map_element "arm.additions", to: :additions
        map_element "arm.deletions", to: :deletions
      end

      def mode
        "arm"
      end
    end
  end
end
