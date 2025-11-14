# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # InspectCommand shows detailed element information
      class InspectCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Display detailed information about a specific element.

          Element format: type:identifier
          - package:ModelRoot::Core
          - class:ModelRoot::Core::Building
          - diagram:ClassDiagram1
          - attribute:ModelRoot::Core::Building::name

          Examples:
            lutaml uml inspect model.lur class:Building
            lutaml uml inspect model.lur package:ModelRoot::Core
            lutaml uml inspect model.lur diagram:Overview
          DESC

          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|yaml|json)"
          thor_class.option :include, type: :array,
                                      desc: "Include sections (attributes, associations, operations)"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path, element_id)
          repo = load_repository(lur_path, lazy: options[:lazy])
          identifier = ElementIdentifier.parse(element_id)

          element = find_element(repo, identifier)
          unless element
            puts OutputFormatter.error("Element not found: #{element_id}")
            exit 1
          end

          display_element_details(element, identifier, repo)
        end

        private

        def find_element(repo, identifier)
          config = ResourceRegistry.config_for(identifier.type)
          return nil unless config

          repo.send(config[:find_method], identifier.path)
        end

        def display_element_details(element, identifier, repo)
          presenter_class_name = ResourceRegistry.config_for(identifier.type)[:presenter]
          presenter_class = Lutaml::Xmi::Presenters.const_get(presenter_class_name)
          presenter = presenter_class.new(element, repo)

          if options[:format] == "text"
            puts presenter.to_text
          else
            puts OutputFormatter.format(presenter.to_hash,
                                        format: options[:format])
          end
        end
      end
    end
  end
end
