require "shale"

module Lutaml
  module Xml
    class Mapper < Shale::Mapper
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/BlockLength
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      class << self
        # Convert XML document to Object
        #
        # @param [Shale::Adapter::<XML adapter>::Node] element
        # @param [Array<Symbol>] only
        # @param [Array<Symbol>] except
        # @param [any] context
        #
        # @return [model instance]
        #
        # @api public
        def of_xml(element, only: nil, except: nil, context: nil)
          instance = model.new

          attributes
            .values
            .select(&:default)
            .each { |attr| instance.send(attr.setter, attr.default.call) }

          grouping = Shale::Mapping::Group::XmlGrouping.new
          delegates = Shale::Mapping::Delegates.new

          only = to_partial_render_attributes(only)
          except = to_partial_render_attributes(except)

          element.attributes.each do |key, value|
            mapping = xml_mapping.attributes[key.to_s]
            next unless mapping

            if mapping.group
              grouping.add(mapping, :attribute, value)
            elsif mapping.method_from
              mapper = new

              if mapper.method(mapping.method_from).arity == 3
                mapper.send(mapping.method_from, instance, value, context)
              else
                mapper.send(mapping.method_from, instance, value)
              end
            else
              receiver_attributes = get_receiver_attributes(mapping)
              attribute = receiver_attributes[mapping.attribute]
              next unless attribute

              next if only && !only.key?(attribute.name)
              next if except&.key?(attribute.name)

              casted_value = attribute.type.cast(value)

              if attribute.collection?
                if mapping.receiver
                  delegates.add_collection(
                    attributes[mapping.receiver],
                    attribute.setter,
                    casted_value,
                  )
                else
                  instance.send(attribute.name) << casted_value
                end
              elsif mapping.receiver
                delegates.add(attributes[mapping.receiver], attribute.setter,
                              casted_value)
              else
                instance.send(attribute.setter, casted_value)
              end
            end
          end

          content_mapping = xml_mapping.content

          if content_mapping
            if content_mapping.group
              grouping.add(content_mapping, :content, element)
            elsif content_mapping.method_from
              mapper = new

              if mapper.method(content_mapping.method_from).arity == 3
                mapper.send(content_mapping.method_from, instance, element,
                            context)
              else
                mapper.send(content_mapping.method_from, instance, element)
              end
            else
              get_content_value(content_mapping, element, only, except,
                                delegates, instance)
            end
          end

          # rubocop:disable Metrics/BlockNesting
          element.instance_variable_get(:@node)&.children&.each do |nokogiri_node|
            if nokogiri_node.name == "text"
              content_value = get_content_value(content_mapping, nokogiri_node,
                                                only, except, delegates, instance)
              instance.all_content << ["content", content_value]
              next
            elsif nokogiri_node.name == "comment"
              instance.all_content << ["comment", nokogiri_node.text]
              next
            end

            node = element.class.new(nokogiri_node)
            mapping = xml_mapping.elements[node.name]

            next unless mapping

            if mapping.group
              grouping.add(mapping, :element, node)
            elsif mapping.method_from
              mapper = new

              if mapper.method(mapping.method_from).arity == 3
                mapper.send(mapping.method_from, instance, node, context)
              else
                mapper.send(mapping.method_from, instance, node)
              end
            else
              receiver_attributes = get_receiver_attributes(mapping)
              attribute = receiver_attributes[mapping.attribute]
              next unless attribute

              if only
                attribute_only = only[attribute.name]
                next unless only.key?(attribute.name)
              end

              if except
                attribute_except = except[attribute.name]
                next if except.key?(attribute.name) && attribute_except.nil?
              end

              value = attribute.type.of_xml(
                node,
                only: attribute_only,
                except: attribute_except,
                context: context,
              )

              casted_value = attribute.type.cast(value)
              instance.all_content << [mapping, casted_value]

              if attribute.collection?
                if mapping.receiver
                  delegates.add_collection(
                    attributes[mapping.receiver],
                    attribute.setter,
                    casted_value,
                  )
                else
                  instance.send(attribute.name) << casted_value
                end
              elsif mapping.receiver
                delegates.add(attributes[mapping.receiver], attribute.setter,
                              casted_value)
              else
                instance.send(attribute.setter, casted_value)
              end
            end
          end
          # rubocop:enable Metrics/BlockNesting

          delegates.each do |delegate|
            receiver = get_receiver(instance, delegate.receiver_attribute)
            receiver.send(delegate.setter, delegate.value)
          end

          grouping.each do |group|
            mapper = new

            if mapper.method(group.method_from).arity == 3
              mapper.send(group.method_from, instance, group.dict, context)
            else
              mapper.send(group.method_from, instance, group.dict)
            end
          end

          instance
        end

        # Convert Object to XML document
        #
        # @param [any] instance Object to convert
        # @param [String, nil] node_name XML node name
        # @param [Shale::Adapter::<xml adapter>::Document, nil]
        #          doc Object to convert
        # @param [Array<Symbol>] only
        # @param [Array<Symbol>] except
        # @param [any] context
        #
        # @raise [IncorrectModelError]
        #
        # @return [::REXML::Document, ::Nokogiri::Document, ::Ox::Document]
        #
        # @api public
        def as_xml(
          instance,
          node_name = nil,
          doc = nil,
          _cdata = nil,
          only: nil,
          except: nil,
          context: nil,
          version: nil
        )
          unless instance.is_a?(model)
            msg = "argument is a '#{instance.class}' but should be a '#{model}'"
            raise IncorrectModelError, msg
          end

          unless doc
            doc = Shale.xml_adapter.create_document(version)

            element = as_xml(
              instance,
              xml_mapping.prefixed_root,
              doc,
              only: only,
              except: except,
              context: context,
            )
            doc.add_element(doc.doc, element)

            return doc.doc
          end

          element = doc.create_element(node_name)

          doc.add_namespace(
            xml_mapping.default_namespace.prefix,
            xml_mapping.default_namespace.name,
          )

          grouping = Shale::Mapping::Group::XmlGrouping.new

          only = to_partial_render_attributes(only)
          except = to_partial_render_attributes(except)

          # rubocop:disable Metrics/BlockNesting
          xml_mapping.attributes.each_value do |mapping|
            if mapping.group
              grouping.add(mapping, :attribute, nil)
            elsif mapping.method_to
              mapper = new

              if mapper.method(mapping.method_to).arity == 4
                mapper.send(mapping.method_to, instance, element, doc, context)
              else
                mapper.send(mapping.method_to, instance, element, doc)
              end
            else
              receiver = if mapping.receiver
                           instance.send(mapping.receiver)
                         else
                           instance
                         end

              receiver_attributes = get_receiver_attributes(mapping)
              attribute = receiver_attributes[mapping.attribute]
              next unless attribute

              next if only && !only.key?(attribute.name)
              next if except&.key?(attribute.name)

              value = receiver.send(attribute.name) if receiver

              if mapping.render_nil? || !value.nil?
                doc.add_namespace(mapping.namespace.prefix,
                                  mapping.namespace.name)
                doc.add_attribute(element, mapping.prefixed_name, value)
              end
            end
          end
          # rubocop:enable Metrics/BlockNesting

          # rubocop:disable Metrics/BlockNesting
          instance.all_content.each do |mapping, content|
            if mapping == "comment"
              comment = Nokogiri::XML::Comment.new(doc.doc, content)
              doc.add_element(element, comment)
            elsif mapping == "content"
              content_mapping = xml_mapping.content
              if content_mapping
                if content_mapping.group
                  grouping.add(content_mapping, :content, nil)
                elsif content_mapping.method_to
                  mapper = new

                  if mapper.method(content_mapping.method_to).arity == 4
                    mapper.send(content_mapping.method_to, instance, element,
                                doc, context)
                  else
                    mapper.send(content_mapping.method_to, instance, element, doc)
                  end
                else
                  receiver_attributes = get_receiver_attributes(content_mapping)
                  attribute = receiver_attributes[content_mapping.attribute]

                  if attribute
                    skip = false

                    skip = true if only && !only.key?(attribute.name)
                    skip = true if except&.key?(attribute.name)

                    unless skip
                      # value = receiver.send(attribute.name) if receiver
                      value = content

                      if content_mapping.cdata
                        doc.create_cdata(value, element)
                      else
                        a = Nokogiri::XML::Text.new(value, doc.doc)
                        doc.add_element(element, a)
                      end
                    end
                  end
                end
              end
            elsif mapping.group
              grouping.add(mapping, :element, nil)
            elsif mapping.method_to
              mapper = new

              if mapper.method(mapping.method_to).arity == 4
                mapper.send(mapping.method_to, instance, element, doc, context)
              else
                mapper.send(mapping.method_to, instance, element, doc)
              end
            else
              receiver_attributes = get_receiver_attributes(mapping)
              attribute = receiver_attributes[mapping.attribute]
              next unless attribute

              if only
                attribute_only = only[attribute.name]
                next unless only.key?(attribute.name)
              end

              if except
                attribute_except = except[attribute.name]
                next if except.key?(attribute.name) && attribute_except.nil?
              end

              value = content

              if mapping.render_nil? || !value.nil?
                doc.add_namespace(mapping.namespace.prefix,
                                  mapping.namespace.name)
              end

              if value.nil?
                if mapping.render_nil?
                  child = doc.create_element(mapping.prefixed_name)
                  doc.add_element(element, child)
                end
              elsif attribute.collection?
                [*value].each do |v|
                  next if v.nil?

                  child = attribute.type.as_xml(
                    v,
                    mapping.prefixed_name,
                    doc,
                    mapping.cdata,
                    only: attribute_only,
                    except: attribute_except,
                    context: context,
                  )
                  doc.add_element(element, child)
                end
              else
                child = attribute.type.as_xml(
                  value,
                  mapping.prefixed_name,
                  doc,
                  mapping.cdata,
                  only: attribute_only,
                  except: attribute_except,
                  context: context,
                )
                doc.add_element(element, child)
              end
            end
          end
          # rubocop:enable Metrics/BlockNesting

          grouping.each do |group|
            mapper = new

            if mapper.method(group.method_to).arity == 4
              mapper.send(group.method_to, instance, element, doc, context)
            else
              mapper.send(group.method_to, instance, element, doc)
            end
          end

          element
        end

        def get_content_value(content_mapping, element, only, except, delegates, instance)
          receiver_attributes = get_receiver_attributes(content_mapping)
          attribute = receiver_attributes[content_mapping.attribute]

          if attribute
            skip = false

            # rubocop:disable Metrics/BlockNesting
            skip = true if only && !only.key?(attribute.name)
            skip = true if except&.key?(attribute.name)

            unless skip
              value = attribute.type.cast(attribute.type.of_xml(element))

              if content_mapping.receiver
                delegates.add(attributes[content_mapping.receiver],
                              attribute.setter, value)
              else
                instance.send(attribute.setter, value)
              end
            end
            # rubocop:enable Metrics/BlockNesting
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/BlockLength
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      attr_accessor :all_content

      def initialize(*args)
        @all_content = []

        super
      end
    end
  end
end
