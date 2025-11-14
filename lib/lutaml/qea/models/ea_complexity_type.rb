# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a complexity type definition from t_complexitytypes table
      #
      # This table provides reference data for complexity levels that can be
      # assigned to UML elements. Each complexity has a numeric weight for
      # sorting/comparison.
      #
      # @example
      #   complexity_type = EaComplexityType.new
      #   complexity_type.complexity #=> "High"
      #   complexity_type.numeric_weight #=> 4
      class EaComplexityType < BaseModel
        attribute :complexity, Lutaml::Model::Type::String
        attribute :numericweight, Lutaml::Model::Type::Integer

        def self.table_name
          "t_complexitytypes"
        end

        # Primary key is Complexity (text)
        def self.primary_key_column
          "Complexity"
        end

        # Friendly name for complexity
        # @return [String]
        def name
          complexity
        end

        # Alias for readability
        alias numeric_weight numericweight

        # Get numeric weight for sorting
        # @return [Integer]
        def weight
          numericweight || 0
        end

        # Check if this is low complexity
        # @return [Boolean]
        def low?
          complexity&.match?(/^(V\.)?Low$/i)
        end

        # Check if this is medium complexity
        # @return [Boolean]
        def medium?
          complexity == "Medium"
        end

        # Check if this is high complexity
        # @return [Boolean]
        def high?
          complexity&.match?(/^(V\.)?High$/i)
        end

        # Check if this is extreme complexity
        # @return [Boolean]
        def extreme?
          complexity == "Extreme"
        end

        # Compare complexity levels by numeric weight
        # @param other [EaComplexityType]
        # @return [Integer] -1, 0, or 1
        def <=>(other)
          return 0 unless other.is_a?(EaComplexityType)

          weight <=> other.weight
        end
      end
    end
  end
end
