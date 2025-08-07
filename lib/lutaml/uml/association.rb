# frozen_string_literal: true

module Lutaml
  module Uml
    class Association < TopElement
      attribute :owner_end, :string
      attribute :owner_end_attribute_name, :string
      attribute :owner_end_cardinality, Cardinality
      attribute :owner_end_type, :string
      attribute :owner_end_xmi_id, :string
      attribute :member_end, :string
      attribute :member_end_attribute_name, :string
      attribute :member_end_xmi_id, :string
      attribute :member_end_cardinality, Cardinality
      attribute :member_end_type, :string
      attribute :static, :string
      attribute :action, Action

      yaml do
        map "owner_end", to: :owner_end
        map "owner_end_attribute_name", to: :owner_end_attribute_name
        map "owner_end_cardinality", to: :owner_end_cardinality
        map "owner_end_type", to: :owner_end_type
        map "owner_end_xmi_id", to: :owner_end_xmi_id
        map "member_end", to: :member_end
        map "member_end_attribute_name", to: :member_end_attribute_name
        map "member_end_xmi_id", to: :member_end_xmi_id
        map "member_end_cardinality", to: :member_end_cardinality
        map "member_end_type", to: :member_end_type
        map "static", to: :static
        map "action", to: :action
      end
    end
  end
end
