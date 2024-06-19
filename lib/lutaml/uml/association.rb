# frozen_string_literal: true

module Lutaml
  module Uml
    class Association < TopElement
      include HasMembers

      attr_accessor :owner_end,
                    :owner_end_attribute_name,
                    :owner_end_cardinality,
                    :owner_end_type,
                    :owner_end_xmi_id,
                    :member_end,
                    :member_end_attribute_name,
                    :member_end_xmi_id,
                    :member_end_cardinality,
                    :member_end_type,
                    :static,
                    :action

      # TODO: move to Parslet::Transform
      def members=(value)
        value.group_by { |member| member.keys.first }
          .each do |(type, group)|
            if %w[owner_end member_end].include?(type)
              group.each do |member|
                member.each_pair do |key, member_value|
                  public_send("#{associtaion_type(key)}=", member_value)
                end
              end
              next
            end
            attribute_value = group.map(&:values).flatten
            if attribute_value.length == 1 && !attribute_value.first.is_a?(Hash)
              next public_send("#{associtaion_type(type)}=", attribute_value.first)
            end

            public_send("#{associtaion_type(type)}=", attribute_value)
          end
      end
    end
  end
end
