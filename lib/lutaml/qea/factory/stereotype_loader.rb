# frozen_string_literal: true

module Lutaml
  module Qea
    module Factory
      class StereotypeLoader
        def initialize(database)
          @database = database
        end

        def load_from_xref(ea_guid)
          return nil if ea_guid.nil?
          return nil unless @database.xrefs

          xref = @database.xrefs.find do |x|
            x.client == ea_guid && x.name == "Stereotypes" &&
              x.type == "element property"
          end

          return nil unless xref

          description = xref.description
          return nil if description.nil? || description.empty?

          if description =~ /@STEREO;Name=([^;]+);/
            return Regexp.last_match(1)
          end

          nil
        end
      end
    end
  end
end
