# frozen_string_literal: true

module UmlRepositoryHelpers
  def create_test_document
    Lutaml::Xmi::Parsers::Xml.parse(File.new(fixtures_path("ea-xmi-2.5.1.xmi")))
  end

  def create_test_repository
    document = create_test_document
    Lutaml::UmlRepository::Repository.new(document: document)
  end

  def create_simple_test_document # rubocop:disable Metrics/AbcSize
    doc = Lutaml::Uml::Document.new
    doc.name = "TestModel"

    # Create a root package
    root_package = Lutaml::Uml::Package.new
    root_package.name = "RootPackage"
    root_package.xmi_id = "root_pkg"

    # Create nested package
    nested_package = Lutaml::Uml::Package.new
    nested_package.name = "NestedPackage"
    nested_package.xmi_id = "nested_pkg"
    root_package.packages << nested_package

    # Create a class
    test_class = Lutaml::Uml::Class.new
    test_class.name = "TestClass"
    test_class.xmi_id = "test_class_id"
    test_class.stereotype = "TestStereotype"
    root_package.classes << test_class

    # Create enum
    test_enum = Lutaml::Uml::Enum.new
    test_enum.name = "TestEnum"
    test_enum.xmi_id = "test_enum_id"
    root_package.enums << test_enum

    doc.packages << root_package
    doc
  end
end

RSpec.configure do |config|
  config.include UmlRepositoryHelpers
end
