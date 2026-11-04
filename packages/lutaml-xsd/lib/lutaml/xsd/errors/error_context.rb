# frozen_string_literal: true

module Lutaml
  module Xsd
    module Errors
      # Value object representing contextual information for enhanced errors
      #
      # @example Creating an error context
      #   context = ErrorContext.new(
      #     location: "/root/element[1]",
      #     namespace: "http://example.com",
      #     expected_type: "xs:string",
      #     actual_value: "123"
      #   )
      class ErrorContext
        # @return [String, nil] XPath location of the error
        attr_reader :location

        # @return [String, nil] Namespace URI
        attr_reader :namespace

        # @return [String, nil] Expected type name
        attr_reader :expected_type

        # @return [String, nil] Actual value that caused the error
        attr_reader :actual_value

        # @return [Lutaml::Xsd::SchemaRepository, nil] Schema repository for suggestions
        attr_reader :repository

        # @return [Hash] Additional context attributes
        attr_reader :additional

        # Initialize error context with attributes
        #
        # @param attrs [Hash] Context attributes
        # @option attrs [String] :location XPath location
        # @option attrs [String] :namespace Namespace URI
        # @option attrs [String] :expected_type Expected type name
        # @option attrs [String] :actual_value Actual value
        # @option attrs [Lutaml::Xsd::SchemaRepository] :repository Schema repository
        def initialize(attrs = {})
          @location = attrs[:location]
          @namespace = attrs[:namespace]
          @expected_type = attrs[:expected_type]
          @actual_value = attrs[:actual_value]
          @repository = attrs[:repository]
          @additional = attrs.except(
            :location, :namespace, :expected_type,
            :actual_value, :repository
          )
        end

        # Convert context to hash representation
        #
        # @return [Hash] Context as hash
        def to_h
          {
            location: @location,
            namespace: @namespace,
            expected_type: @expected_type,
            actual_value: @actual_value,
          }.merge(@additional).compact
        end

        # Check if context has repository for suggestions
        #
        # @return [Boolean] True if repository is available
        def has_repository?
          !@repository.nil?
        end
      end
    end
  end
end
