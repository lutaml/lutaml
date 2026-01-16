# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea"

RSpec.describe Lutaml::Qea::Factory::EaToUmlFactory do
  let(:qea_file) { "examples/qea/20251010_current_plateau_v5.1.qea" }
  let(:database) { Lutaml::Qea.load_database(qea_file) }
  let(:factory) { described_class.new(database) }

  after do
    if database.connection && !database.connection.closed?
      database.connection&.close
    end
  end

  describe "#create_document" do
    it "creates a document with packages but no classes at document level" do
      document = factory.create_document

      expect(document).to be_a(Lutaml::Uml::Document)
      expect(document.packages).not_to be_empty
      expect(document.classes).to be_empty
    end

    it "nests classes in their correct packages according to Package_ID" do
      document = factory.create_document

      # Helper to count classes recursively in packages
      def count_classes_in_packages(packages)
        packages.sum do |pkg|
          pkg.classes.size + count_classes_in_packages(pkg.packages || [])
        end
      end

      classes_in_packages = count_classes_in_packages(document.packages)

      expect(classes_in_packages).to be > 0
      expect(document.classes.size).to eq(0)
    end

    it "preserves package hierarchy from database" do
      document = factory.create_document

      # Find a nested class and verify its package path
      def find_class_in_packages(packages, class_name, path = [])
        packages.each do |pkg|
          current_path = path + [pkg.name]

          # Check classes in this package
          pkg.classes.each do |klass|
            if klass.name == class_name
              return { class: klass,
                       path: current_path }
            end
          end

          # Recursively check child packages
          if pkg.packages
            result = find_class_in_packages(pkg.packages, class_name,
                                            current_path)
            return result if result
          end
        end
        nil
      end

      # _CityObject should be in core package
      result = find_class_in_packages(document.packages, "_CityObject")

      expect(result).not_to be_nil
      expect(result[:class].name).to eq("_CityObject")
      expect(result[:path]).to include("core")
      expect(result[:path].size).to be > 1 # Should have parent packages
    end

    it "creates associations that reference classes by xmi_id" do
      document = factory.create_document

      expect(document.associations).not_to be_empty

      # Sample an association
      association = document.associations.first
      expect(association).to be_a(Lutaml::Uml::Association)
    end
  end

  describe "package hierarchy correctness" do
    it "does not duplicate classes between packages and document level" do
      document = factory.create_document

      # Collect all class xmi_ids from packages
      def collect_class_xmi_ids(packages, ids = [])
        packages.each do |pkg|
          ids.concat(pkg.classes.map(&:xmi_id))
          collect_class_xmi_ids(pkg.packages || [], ids)
        end
        ids
      end

      package_class_ids = collect_class_xmi_ids(document.packages)
      document_class_ids = document.classes.map(&:xmi_id)

      # No overlap should exist
      overlap = package_class_ids & document_class_ids
      expect(overlap).to be_empty
    end
  end
end