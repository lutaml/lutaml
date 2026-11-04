# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Namespace registry when loading from package" do
  let(:temp_dir) do
    dir = File.join(Dir.pwd, "tmp_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(dir)
    dir
  end
  let(:xsd_content) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:test="http://example.com/test"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:complexType name="TestType">
          <xs:sequence>
            <xs:element name="value" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
      </xs:schema>
    XSD
  end

  let(:xsd_file) { File.join(temp_dir, "test.xsd") }
  let(:package_file) { File.join(temp_dir, "test.lxr") }

  before do
    File.write(xsd_file, xsd_content)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  it "registers namespace mappings when loading from package" do
    # Create repository and package
    repo = Lutaml::Xsd::SchemaRepository.new(
      files: [xsd_file],
      namespace_mappings: [
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "test",
          uri: "http://example.com/test",
        ),
      ],
    )
    repo.parse.resolve

    # Create package
    repo.to_package(
      package_file,
      xsd_mode: :include_all,
      resolution_mode: :resolved,
      serialization_format: :marshal,
    )

    # Load from package
    loaded_repo = Lutaml::Xsd::SchemaRepository.from_package(package_file)
    loaded_repo.resolve unless loaded_repo.instance_variable_get(:@resolved)

    # Verify namespace mappings are present in repository
    expect(loaded_repo.namespace_mappings).not_to be_empty
    expect(loaded_repo.namespace_mappings.size).to eq(1)
    expect(loaded_repo.namespace_mappings.first.prefix).to eq("test")
    expect(loaded_repo.namespace_mappings.first.uri).to eq("http://example.com/test")

    # Verify namespace mappings are registered in the namespace registry
    registry = loaded_repo.instance_variable_get(:@namespace_registry)
    expect(registry.get_uri("test")).to eq("http://example.com/test")
    expect(registry.prefix_registered?("test")).to be true

    # Verify we can find types using the prefix
    result = loaded_repo.find_type("test:TestType")
    expect(result.resolved?).to be true
    expect(result.local_name).to eq("TestType")
    expect(result.namespace).to eq("http://example.com/test")
  end

  it "does not raise 'Namespace prefix not registered' error when finding types" do
    # Create repository and package
    repo = Lutaml::Xsd::SchemaRepository.new(
      files: [xsd_file],
      namespace_mappings: [
        Lutaml::Xsd::NamespaceMapping.new(
          prefix: "test",
          uri: "http://example.com/test",
        ),
      ],
    )
    repo.parse.resolve

    # Create package
    repo.to_package(
      package_file,
      xsd_mode: :include_all,
      resolution_mode: :resolved,
      serialization_format: :marshal,
    )

    # Load from package and attempt to find type
    loaded_repo = Lutaml::Xsd::SchemaRepository.from_package(package_file)
    loaded_repo.resolve unless loaded_repo.instance_variable_get(:@resolved)

    # This should NOT raise an error
    expect { loaded_repo.find_type("test:TestType") }.not_to raise_error

    # And should successfully resolve the type
    result = loaded_repo.find_type("test:TestType")
    expect(result.resolved?).to be true
  end
end
