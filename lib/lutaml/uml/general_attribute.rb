# frozen_string_literal: true

module Lutaml
  module Uml
    class GeneralAttribute < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :type, :string
      attribute :xmi_id, :string
      attribute :is_derived, :boolean, default: false
      attribute :cardinality, Cardinality
      attribute :definition, :string
      attribute :association, :string
      attribute :has_association, :boolean, default: false
      attribute :type_ns, :string
      attribute :name_ns, :string
      attribute :gen_name, :string
      attribute :upper_klass, :string
      attribute :level, :integer
    end
  end
end
