# frozen_string_literal: true

module Lutaml
  module Xml
    module Schema
      module Xsd
        # Attributes added by reopening don't participate in XML deserialization,
        # so they get Lutaml::Model::UninitializedClass (a truthy sentinel).
        # Override getters to return nil instead.
        module UninitializedGuard
          def self.guard(klass, *names)
            mod = Module.new do
              names.each do |name|
                define_method(name) do
                  val = super()
                  ::Lutaml::Model::Utils.uninitialized?(val) ? nil : val
                end
              end
            end
            klass.prepend(mod)
          end
        end

        class ComplexType < Base
          attribute :restriction, :restriction_complex_content
          attribute :type, :string
        end
        UninitializedGuard.guard(ComplexType, :restriction, :type)

        class SimpleType < Base
          attribute :sequence, :sequence
          attribute :choice, :choice
          attribute :all, :all
          attribute :group, :group
          attribute :type, :string
          attribute :complex_content, :complex_content
          attribute :simple_content, :simple_content
          attribute :attribute, :attribute, collection: true,
                                            initialize_empty: true
          attribute :attribute_group, :attribute_group, collection: true,
                                                        initialize_empty: true
        end
        UninitializedGuard.guard(SimpleType, :sequence, :choice, :all, :group,
                                 :type, :complex_content, :simple_content)

        class Element < Base
          attribute :target_namespace, :string
          attribute :complex_content, :complex_content
          attribute :simple_content, :simple_content
          attribute :sequence, :sequence
          attribute :choice, :choice
          attribute :all, :all
          attribute :group, :group
          attribute :restriction, :restriction_simple_type
          attribute :attribute, :attribute, collection: true,
                                            initialize_empty: true
          attribute :attribute_group, :attribute_group, collection: true,
                                                        initialize_empty: true
        end
        UninitializedGuard.guard(Element, :target_namespace, :complex_content,
                                 :simple_content, :sequence, :choice, :all,
                                 :group, :restriction)

        # lutaml-model maps xs:all's occurrence bounds from the Ruby
        # attribute names (`min_occurs`) instead of the XML ones, so
        # minOccurs/maxOccurs on xs:all deserialize as nil. Re-map with
        # the XML names until the upstream mapping is fixed.
        class All < Base
          xml do
            map_attribute :minOccurs, to: :min_occurs
            map_attribute :maxOccurs, to: :max_occurs
          end
        end
      end
    end
  end
end
