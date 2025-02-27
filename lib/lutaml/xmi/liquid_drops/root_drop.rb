# frozen_string_literal: true

module Lutaml
  module XMI
    class RootDrop < Liquid::Drop
      def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper,Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
        @model = model
        @guidance = guidance
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @xmi_cache = options[:xmi_cache]

        @options[:absolute_path] = "::#{model.name}"

        @packages = model&.packaged_element&.select do |e|
          e.type?("uml:Package")
        end

        @children_packages ||= packages.map do |pkg|
          [pkg, pkg.packages, pkg.packages.map(&:children_packages)]
        end.flatten.uniq
      end

      def name
        @model.name
      end

      def packages
        @packages.map do |package|
          ::Lutaml::XMI::PackageDrop.new(package, @guidance, @options)
        end
      end

      def children_packages
        @children_packages
      end
    end
  end
end
