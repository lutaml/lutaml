# frozen_string_literal: true

module Lutaml
  module XMI
    class PackageDrop < Liquid::Drop
      def initialize(model, guidance = nil) # rubocop:disable Lint/MissingSuper
        @model = model
        @guidance = guidance

        @children_packages ||= packages.map do |pkg|
          [pkg, pkg.packages, pkg.packages.map(&:children_packages)]
        end.flatten.uniq
      end

      def xmi_id
        @model[:xmi_id]
      end

      def name
        @model[:name]
      end

      def absolute_path
        @model[:absolute_path]
      end

      def klasses
        @model[:classes].map do |klass|
          ::Lutaml::XMI::KlassDrop.new(klass, @guidance)
        end
      end
      alias classes klasses

      def enums
        @model[:enums].map do |enum|
          ::Lutaml::XMI::EnumDrop.new(enum)
        end
      end

      def data_types
        @model[:data_types].map do |data_type|
          ::Lutaml::XMI::DataTypeDrop.new(data_type)
        end
      end

      def diagrams
        @model[:diagrams].map do |diagram|
          ::Lutaml::XMI::DiagramDrop.new(diagram)
        end
      end

      def packages
        @model[:packages].map do |package|
          ::Lutaml::XMI::PackageDrop.new(package, @guidance)
        end
      end

      def children_packages
        @children_packages
      end

      def definition
        @model[:definition]
      end

      def stereotype
        @model[:stereotype]
      end
    end
  end
end
