# frozen_string_literal: true

module Lutaml
  module Uml
    module HasMembers
      class UnknownMemberTypeError < StandardError; end

      # TODO: move to Parslet::Transform
      def members=(value) # rubocop:disable Metrics/AbcSize
        value.group_by { |member| member.keys.first }
          .each do |(type, group)|
            attribute_value = group.map(&:values).flatten
            if attribute_value.length == 1 && !attribute_value.first.is_a?(Hash)
              next public_send(:"#{association_type(type)}=",
                               attribute_value.first)
            end

            public_send(:"#{association_type(type)}=", attribute_value)
          end
      end

      private

      def association_type(type)
        return type if respond_to?(:"#{type}=")

        raise(UnknownMemberTypeError, "Unknown member type: #{type}")
      end
    end
  end
end
