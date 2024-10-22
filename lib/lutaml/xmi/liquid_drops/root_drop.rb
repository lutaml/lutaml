# frozen_string_literal: true

module Lutaml
  module XMI
    class RootDrop < Liquid::Drop
      def initialize(model, guidance = nil) # rubocop:disable Lint/MissingSuper
        @model = model
        @guidance = guidance
        @children_packages ||= packages.map do |pkg|
          [pkg, pkg.packages, pkg.packages.map(&:children_packages)]
        end.flatten.uniq
      end

      def name
        @model[:name]
      end

      def packages
        @model[:packages].map do |package|
          ::Lutaml::XMI::PackageDrop.new(package, @guidance)
        end
      end

      def children_packages
        @children_packages
      end
    end
  end
end
