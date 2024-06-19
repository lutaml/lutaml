# frozen_string_literal: true

module Lutaml
  module Uml
    class TopElement
      include HasAttributes

      attr_accessor :name,
                    :definition,
                    :xmi_id,
                    :xmi_uuid,
                    :namespace,
                    :keyword,
                    :stereotype,
                    :href,
                    :visibility,
                    :comments

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        @visibility = "public"
        @name = attributes["name"]
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases

      def full_name
        if name == nil
          return nil
        end

        the_name = name
        next_namespace = namespace

        while !next_namespace.nil?
          the_name = if !next_namespace.name.nil?
                       next_namespace.name + "::" + the_name
                     else
                       "::" + the_name
                     end
          next_namespace = next_namespace.namespace
        end

        the_name
      end

      def definition=(value)
        @definition = value
                        .to_s
                        .gsub(/\\}/, '}')
                        .gsub(/\\{/, '{')
                        .split("\n")
                        .map(&:strip)
                        .join("\n")
      end
    end
  end
end
