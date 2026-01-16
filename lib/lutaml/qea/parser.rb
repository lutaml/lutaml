# frozen_string_literal: true

require_relative "../qea"
require_relative "services/database_loader"
require_relative "factory/ea_to_uml_factory"

module Lutaml
  module Qea
    # Parser class provides backward compatibility wrapper for Qea.parse
    #
    # This class exists for compatibility with older code that uses
    # Qea::Parser.parse instead of the newer Qea.parse method.
    #
    # For validation use cases, this returns both database and document.
    # For simple parsing, use Qea.parse directly which returns just document.
    #
    # @example Parse a QEA file for validation
    #   result = Lutaml::Qea::Parser.new.parse("model.qea")
    #   document = result[:document]
    #   database = result[:database]
    #
    # @see Qea.parse
    class Parser
      class << self
        # Parse a QEA file and return document only
        #
        # This is a backward compatibility wrapper that delegates to Qea.parse
        #
        # @param qea_path [String] Path to the .qea file
        # @param options [Hash] Transformation options
        # @return [Lutaml::Uml::Document] Complete UML document
        #
        # @see Qea.parse
        def parse(qea_path, options = {})
          Qea.parse(qea_path, options)
        end
      end

      # Instance method for compatibility with test expectations
      # @param qea_path [String] Path to the .qea file
      # @param options [Hash] Transformation options
      # @return [Hash] Hash with :database and :document keys
      def parse(qea_path, options = {}) # rubocop:disable Metrics/MethodLength
        # Load database
        config = options[:config]
        loader = Services::DatabaseLoader.new(qea_path, config)
        database = loader.load

        # Create document
        factory = Factory::EaToUmlFactory.new(database, options)
        document = factory.create_document

        # Return both for validation support
        {
          database: database,
          document: document,
        }
      end
    end
  end
end
