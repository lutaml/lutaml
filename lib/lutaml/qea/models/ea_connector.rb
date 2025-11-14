# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a connector from the t_connector table in EA database
      # This represents relationships between objects (associations,
      # generalizations, dependencies, etc.)
      class EaConnector < BaseModel
        attribute :connector_id, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :direction, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :connector_type, Lutaml::Model::Type::String
        attribute :subtype, Lutaml::Model::Type::String
        attribute :sourcecard, Lutaml::Model::Type::String
        attribute :sourceaccess, Lutaml::Model::Type::String
        attribute :sourceelement, Lutaml::Model::Type::String
        attribute :destcard, Lutaml::Model::Type::String
        attribute :destaccess, Lutaml::Model::Type::String
        attribute :destelement, Lutaml::Model::Type::String
        attribute :sourcerole, Lutaml::Model::Type::String
        attribute :sourceroletype, Lutaml::Model::Type::String
        attribute :sourcerolenote, Lutaml::Model::Type::String
        attribute :sourcecontainment, Lutaml::Model::Type::String
        attribute :sourceisaggregate, Lutaml::Model::Type::Integer
        attribute :sourceisordered, Lutaml::Model::Type::Integer
        attribute :sourcequalifier, Lutaml::Model::Type::String
        attribute :destrole, Lutaml::Model::Type::String
        attribute :destroletype, Lutaml::Model::Type::String
        attribute :destrolenote, Lutaml::Model::Type::String
        attribute :destcontainment, Lutaml::Model::Type::String
        attribute :destisaggregate, Lutaml::Model::Type::Integer
        attribute :destisordered, Lutaml::Model::Type::Integer
        attribute :destqualifier, Lutaml::Model::Type::String
        attribute :start_object_id, Lutaml::Model::Type::Integer
        attribute :end_object_id, Lutaml::Model::Type::Integer
        attribute :top_start_label, Lutaml::Model::Type::String
        attribute :top_mid_label, Lutaml::Model::Type::String
        attribute :top_end_label, Lutaml::Model::Type::String
        attribute :btm_start_label, Lutaml::Model::Type::String
        attribute :btm_mid_label, Lutaml::Model::Type::String
        attribute :btm_end_label, Lutaml::Model::Type::String
        attribute :start_edge, Lutaml::Model::Type::Integer
        attribute :end_edge, Lutaml::Model::Type::Integer
        attribute :ptstartx, Lutaml::Model::Type::Integer
        attribute :ptstarty, Lutaml::Model::Type::Integer
        attribute :ptendx, Lutaml::Model::Type::Integer
        attribute :ptendy, Lutaml::Model::Type::Integer
        attribute :seqno, Lutaml::Model::Type::Integer
        attribute :headstyle, Lutaml::Model::Type::Integer
        attribute :linestyle, Lutaml::Model::Type::Integer
        attribute :routestyle, Lutaml::Model::Type::Integer
        attribute :isbold, Lutaml::Model::Type::Integer
        attribute :linecolor, Lutaml::Model::Type::Integer
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :virtualinheritance, Lutaml::Model::Type::String
        attribute :linkaccess, Lutaml::Model::Type::String
        attribute :pdata1, Lutaml::Model::Type::String
        attribute :pdata2, Lutaml::Model::Type::String
        attribute :pdata3, Lutaml::Model::Type::String
        attribute :pdata4, Lutaml::Model::Type::String
        attribute :pdata5, Lutaml::Model::Type::String
        attribute :diagramid, Lutaml::Model::Type::Integer
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :sourceconstraint, Lutaml::Model::Type::String
        attribute :destconstraint, Lutaml::Model::Type::String
        attribute :sourceisnavigable, Lutaml::Model::Type::Integer
        attribute :destisnavigable, Lutaml::Model::Type::Integer
        attribute :isroot, Lutaml::Model::Type::Integer
        attribute :isleaf, Lutaml::Model::Type::Integer
        attribute :isspec, Lutaml::Model::Type::Integer
        attribute :sourcechangeable, Lutaml::Model::Type::String
        attribute :destchangeable, Lutaml::Model::Type::String
        attribute :sourcets, Lutaml::Model::Type::String
        attribute :destts, Lutaml::Model::Type::String
        attribute :stateflags, Lutaml::Model::Type::String
        attribute :actionflags, Lutaml::Model::Type::String
        attribute :issignal, Lutaml::Model::Type::Integer
        attribute :isstimulus, Lutaml::Model::Type::Integer
        attribute :dispatchaction, Lutaml::Model::Type::String
        attribute :target2, Lutaml::Model::Type::Integer
        attribute :styleex, Lutaml::Model::Type::String
        attribute :sourcestereotype, Lutaml::Model::Type::String
        attribute :deststereotype, Lutaml::Model::Type::String
        attribute :sourcestyle, Lutaml::Model::Type::String
        attribute :deststyle, Lutaml::Model::Type::String
        attribute :eventflags, Lutaml::Model::Type::String

        def self.primary_key_column
          :connector_id
        end

        def self.table_name
          "t_connector"
        end

        # Check if connector is an association
        # @return [Boolean]
        def association?
          connector_type == "Association"
        end

        # Check if connector is a generalization
        # @return [Boolean]
        def generalization?
          connector_type == "Generalization"
        end

        # Check if connector is a dependency
        # @return [Boolean]
        def dependency?
          connector_type == "Dependency"
        end

        # Check if connector is an aggregation
        # @return [Boolean]
        def aggregation?
          connector_type == "Aggregation"
        end

        # Check if connector is a realization
        # @return [Boolean]
        def realization?
          connector_type == "Realization"
        end

        # Check if source is aggregate
        # @return [Boolean]
        def source_aggregate?
          sourceisaggregate == 1
        end

        # Check if destination is aggregate
        # @return [Boolean]
        def dest_aggregate?
          destisaggregate == 1
        end

        # Check if source is navigable
        # @return [Boolean]
        def source_navigable?
          sourceisnavigable == 1
        end

        # Check if destination is navigable
        # @return [Boolean]
        def dest_navigable?
          destisnavigable == 1
        end

        # Check if line is bold
        # @return [Boolean]
        def bold?
          isbold == 1
        end
      end
    end
  end
end
