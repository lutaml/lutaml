require "lutaml/lutaml_path/document_wrapper"

module Lutaml
  module Xml
    module LutamlPath
      class DocumentWrapper < ::Lutaml::LutamlPath::DocumentWrapper
        protected

        def serialize_document(document)
          serialize_to_hash(document)
        end

        # TODO: to be removed
        def serialize_to_hash(object)
          hash = {}
          attribute_name = nil

          object.all_content.each do |mapping, content|
            if mapping == "content"
              attribute_name = object.class.xml_mapping.content.attribute.to_s
              hash[attribute_name] ||= []
              hash[attribute_name] << content.strip unless content.strip &&
                content.strip.empty?
            elsif content.is_a?(String)
              if object.class.attributes[mapping.attribute].collection?
                hash[mapping.name] ||= []
                hash[mapping.name] << content.strip
              else
                hash[mapping.name] = content.strip
              end
            elsif object.class.attributes[mapping.attribute].collection?
              hash[mapping.name] ||= []
              hash[mapping.name] << serialize_to_hash(content)
            else
              hash[mapping.name] = serialize_to_hash(content)
            end
          end

          hash[attribute_name] = hash[attribute_name].compact if attribute_name
          hash
        end
      end
    end
  end
end
