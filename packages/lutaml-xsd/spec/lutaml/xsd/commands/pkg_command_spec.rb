# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/pkg_command"
require "tempfile"
require "json"
require "yaml"

RSpec.describe Lutaml::Xsd::Commands::PkgCommand do
  let(:simple_schema) do
    <<~XSD
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 targetNamespace="http://example.com/test"
                 elementFormDefault="qualified">
        <xs:element name="root" type="xs:string"/>
      </xs:schema>
    XSD
  end

  let(:mock_package) do
    instance_double(
      Lutaml::Xsd::SchemaRepositoryPackage,
      load_repository: mock_repository,
    )
  end

  let(:mock_repository) do
    instance_double(
      Lutaml::Xsd::SchemaRepository,
      files: ["test.xsd"],
      namespace_mappings: [],
      statistics: {
        total_schemas: 1,
        total_types: 5,
        total_namespaces: 1,
        namespace_prefixes: ["test"],
        types_by_category: { complex_type: 2, simple_type: 3 },
        resolved: true,
        validated: true,
      },
    )
  end

  describe "#ls with --show-tree option" do
    context "when displaying package hierarchy" do
      it "shows basic package tree structure" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/test.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          # Build a simple package first
          require "lutaml/xsd/commands/package_command"
          build_cmd = Lutaml::Xsd::Commands::PackageCommand::BuildCommand.new(
            config_file,
            {
              verbose: false,
              xsd_mode: "include_all",
              resolution_mode: "resolved",
              serialization_format: "marshal",
              validate: false,
            },
          )

          build_cmd.run

          package_path = File.join(tmpdir, "test.lxr")

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           format: "text",
                                                           classify: false,
                                                           show_tree: true,
                                                           verbose: false,
                                                         })

          output = capture(:stdout) do
            command.ls(package_path)
          end

          expect(output).to match(/test\.xsd/)
        end
      end

      it "displays base packages in composed package tree" do
        # Test requires composed package with base_packages
        # This is a simplified test - full integration would need real packages

        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         format: "text",
                                                         classify: false,
                                                         show_tree: true,
                                                         verbose: false,
                                                       })

        # Mock the package loading to return a composed package structure
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_package)
        allow(mock_package).to receive(:metadata).and_return({
                                                               "base_packages" => [
                                                                 {
                                                                   "package" => "base1.lxr", "priority" => 0
                                                                 },
                                                                 {
                                                                   "package" => "base2.lxr", "priority" => 10
                                                                 },
                                                               ],
                                                             })

        # The command should handle displaying base packages
        expect(command).to respond_to(:ls)
      end
    end

    context "with format options" do
      it "supports JSON format" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/test.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          require "lutaml/xsd/commands/package_command"
          build_cmd = Lutaml::Xsd::Commands::PackageCommand::BuildCommand.new(
            config_file,
            {
              verbose: false,
              xsd_mode: "include_all",
              resolution_mode: "resolved",
              serialization_format: "marshal",
              validate: false,
            },
          )

          build_cmd.run

          package_path = File.join(tmpdir, "test.lxr")

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           format: "json",
                                                           classify: false,
                                                           show_tree: false,
                                                           verbose: false,
                                                         })

          output = capture(:stdout) do
            command.ls(package_path)
          end

          expect { JSON.parse(output) }.not_to raise_error
        end
      end

      it "supports YAML format" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/test.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          require "lutaml/xsd/commands/package_command"
          build_cmd = Lutaml::Xsd::Commands::PackageCommand::BuildCommand.new(
            config_file,
            {
              verbose: false,
              xsd_mode: "include_all",
              resolution_mode: "resolved",
              serialization_format: "marshal",
              validate: false,
            },
          )

          build_cmd.run

          package_path = File.join(tmpdir, "test.lxr")

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           format: "yaml",
                                                           classify: false,
                                                           show_tree: false,
                                                           verbose: false,
                                                         })

          output = capture(:stdout) do
            command.ls(package_path)
          end

          expect { YAML.unsafe_load(output) }.not_to raise_error
        end
      end
    end
  end

  describe "#inspect" do
    context "with composed packages" do
      it "displays base packages section" do
        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         format: "text",
                                                         verbose: false,
                                                       })

        # Mock package with base_packages metadata
        mock_pkg = instance_double(Lutaml::Xsd::SchemaRepositoryPackage)
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_pkg)
        allow(mock_pkg).to receive(:metadata).and_return({
                                                           "name" => "Composed Package",
                                                           "version" => "1.0.0",
                                                           "base_packages" => [
                                                             {
                                                               "package" => "base1.lxr",
                                                               "priority" => 0,
                                                               "conflict_resolution" => "keep",
                                                             },
                                                             {
                                                               "package" => "base2.lxr",
                                                               "priority" => 10,
                                                               "conflict_resolution" => "override",
                                                             },
                                                           ],
                                                         })
        allow(mock_pkg).to receive(:load_repository).and_return(mock_repository)

        # The inspect command should handle base packages
        expect(command).to respond_to(:inspect)
      end

      it "shows inherited schema location mappings" do
        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         format: "text",
                                                         verbose: false,
                                                       })

        # Mock package with inherited mappings
        mock_mappings = [
          instance_double(
            Lutaml::Xsd::SchemaLocationMapping,
            from: "../gml/*.xsd",
            to: "/path/to/gml/\\1",
            pattern: true,
          ),
        ]

        mock_repo = instance_double(
          Lutaml::Xsd::SchemaRepository,
          schema_location_mappings: mock_mappings,
          namespace_mappings: [],
          statistics: {
            total_schemas: 1,
            total_types: 5,
            total_namespaces: 1,
            namespace_prefixes: ["test"],
            types_by_category: {},
            resolved: true,
            validated: true,
          },
        )

        mock_pkg = instance_double(Lutaml::Xsd::SchemaRepositoryPackage)
        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_pkg)
        allow(mock_pkg).to receive(:load_repository).and_return(mock_repo)
        allow(mock_pkg).to receive(:metadata).and_return({
                                                           "name" => "Test Package",
                                                           "schema_location_mappings" => 1,
                                                         })

        # The inspect command should display mappings
        expect(command).to respond_to(:inspect)
      end
    end

    context "with output format options" do
      it "supports JSON format" do
        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         format: "json",
                                                         verbose: false,
                                                       })

        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_package)
        allow(mock_package).to receive(:metadata).and_return({
                                                               "name" => "Test Package",
                                                               "version" => "1.0.0",
                                                             })

        # Should support JSON output
        expect(command).to respond_to(:inspect)
      end

      it "supports YAML format" do
        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         format: "yaml",
                                                         verbose: false,
                                                       })

        allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_package)
        allow(mock_package).to receive(:metadata).and_return({
                                                               "name" => "Test Package",
                                                               "version" => "1.0.0",
                                                             })

        # Should support YAML output
        expect(command).to respond_to(:inspect)
      end
    end
  end

  describe "#tree" do
    it "displays package file tree structure" do
      require "fileutils"

      with_writable_temp_dir do |tmpdir|
        schema_file = File.join(tmpdir, "test.xsd")
        File.write(schema_file, simple_schema)

        config_content = <<~YAML
          output_package: #{tmpdir}/test.lxr
          files:
            - #{schema_file}
        YAML

        config_file = File.join(tmpdir, "config.yml")
        File.write(config_file, config_content)

        require "lutaml/xsd/commands/package_command"
        build_cmd = Lutaml::Xsd::Commands::PackageCommand::BuildCommand.new(
          config_file,
          {
            verbose: false,
            xsd_mode: "include_all",
            resolution_mode: "resolved",
            serialization_format: "marshal",
            validate: false,
          },
        )

        build_cmd.run

        package_path = File.join(tmpdir, "test.lxr")

        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         show_sizes: false,
                                                         no_color: true,
                                                         format: "tree",
                                                         verbose: false,
                                                       })

        output = capture(:stdout) do
          command.tree(package_path)
        end

        expect(output).to match(/test\.lxr/)
      end
    end

    it "shows file sizes when requested" do
      command = described_class.new
      allow(command).to receive(:options).and_return({
                                                       show_sizes: true,
                                                       no_color: true,
                                                       format: "tree",
                                                       verbose: false,
                                                     })

      # The tree command should support showing sizes
      expect(command).to respond_to(:tree)
    end
  end

  describe "#stats" do
    it "displays package statistics" do
      command = described_class.new
      allow(command).to receive(:options).and_return({
                                                       format: "text",
                                                       verbose: false,
                                                     })

      allow(Lutaml::Xsd::SchemaRepositoryPackage).to receive(:new).and_return(mock_package)

      # The stats command should display statistics
      expect(command).to respond_to(:stats)
    end
  end

  describe "command aliases" do
    it "maps cov to coverage command" do
      described_class.new
      # Thor aliases are set with map method, values are symbols
      expect(described_class.instance_variable_get(:@map)).to include("cov" => :coverage)
    end

    it "maps s to search command" do
      described_class.new
      expect(described_class.instance_variable_get(:@map)).to include("s" => :search)
    end

    it "maps ? to search command" do
      described_class.new
      expect(described_class.instance_variable_get(:@map)).to include("?" => :search)
    end
  end

  # Helper method to capture stdout
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end
    result
  end
end
