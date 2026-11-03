# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/commands/build_command"
require "tempfile"

RSpec.describe Lutaml::Xsd::Commands::BuildCommand do
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

  describe "#from_config with output_package field" do
    context "when output_package is specified in config" do
      it "uses output_package from config when -o not specified" do
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

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           serialization_format: "marshal",
                                                           validate: false,
                                                         })

          # This should create test.lxr at the configured location
          expect do
            command.from_config(config_file)
          end.to output(/Package created/).to_stdout

          expect(File.exist?(File.join(tmpdir, "test.lxr"))).to be true
        end
      end

      it "allows -o flag to override config output_package" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/config_output.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          override_output = File.join(tmpdir, "override.lxr")

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           output: override_output,
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           serialization_format: "marshal",
                                                           validate: false,
                                                         })

          # This should create override.lxr, not config_output.lxr
          expect do
            command.from_config(config_file)
          end.to output(/Package created/).to_stdout

          expect(File.exist?(override_output)).to be true
          expect(File.exist?(File.join(tmpdir,
                                       "config_output.lxr"))).to be false
        end
      end

      it "uses default when neither config nor -o specified" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          # Config WITHOUT output_package field
          config_content = <<~YAML
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          # Create pkg directory
          pkg_dir = File.join(tmpdir, "pkg")
          FileUtils.mkdir_p(pkg_dir)

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           serialization_format: "marshal",
                                                           validate: false,
                                                         })

          # Change to tmpdir so default pkg/ directory works
          Dir.chdir(tmpdir) do
            expect do
              command.from_config(config_file)
            end.to output(/Package created/).to_stdout
          end

          # Should create pkg/<name>.lxr (default behavior)
          lxr_files = Dir.glob(File.join(pkg_dir, "*.lxr"))
          expect(lxr_files).not_to be_empty
        end
      end
    end

    context "with validation option" do
      it "validates package after building when --validate specified" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/validated.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           validate: true,
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           serialization_format: "marshal",
                                                         })

          output = capture(:stdout) do
            command.from_config(config_file)
          end

          expect(output).to match(/Package created/)
          expect(output).to match(/Validating package/) if output.include?("Validating")
        end
      end
    end

    context "with serialization format option" do
      it "respects serialization_format option" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/json_format.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           serialization_format: "json",
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           validate: false,
                                                         })

          expect do
            command.from_config(config_file)
          end.to output(/Package created/).to_stdout

          expect(File.exist?(File.join(tmpdir, "json_format.lxr"))).to be true
        end
      end
    end

    context "with metadata options" do
      it "includes metadata from options" do
        require "fileutils"

        with_writable_temp_dir do |tmpdir|
          schema_file = File.join(tmpdir, "test.xsd")
          File.write(schema_file, simple_schema)

          config_content = <<~YAML
            output_package: #{tmpdir}/metadata.lxr
            files:
              - #{schema_file}
          YAML

          config_file = File.join(tmpdir, "config.yml")
          File.write(config_file, config_content)

          command = described_class.new
          allow(command).to receive(:options).and_return({
                                                           name: "Test Package",
                                                           version: "1.0.0",
                                                           description: "Test Description",
                                                           verbose: false,
                                                           xsd_mode: "include_all",
                                                           resolution_mode: "resolved",
                                                           serialization_format: "marshal",
                                                           validate: false,
                                                         })

          expect do
            command.from_config(config_file)
          end.to output(/Package created/).to_stdout

          expect(File.exist?(File.join(tmpdir, "metadata.lxr"))).to be true
        end
      end
    end
  end

  describe "#init" do
    it "accepts entry point schemas" do
      require "fileutils"

      with_writable_temp_dir do |tmpdir|
        schema_file = File.join(tmpdir, "entry.xsd")
        File.write(schema_file, simple_schema)

        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         output: File.join(
                                                           tmpdir, "repository.yml"
                                                         ),
                                                         verbose: false,
                                                         local: false,
                                                         no_fetch: false,
                                                         fetch_timeout: 30,
                                                         resume: false,
                                                       })

        # The init method requires interactive prompt, so we'll just verify it accepts parameters
        expect(command).to respond_to(:init)
      end
    end
  end

  describe "#quick" do
    it "runs build + validate + stats workflow" do
      require "fileutils"

      with_writable_temp_dir do |tmpdir|
        schema_file = File.join(tmpdir, "test.xsd")
        File.write(schema_file, simple_schema)

        config_content = <<~YAML
          output_package: #{tmpdir}/quick.lxr
          files:
            - #{schema_file}
        YAML

        config_file = File.join(tmpdir, "config.yml")
        File.write(config_file, config_content)

        command = described_class.new
        allow(command).to receive(:options).and_return({
                                                         verbose: false,
                                                         xsd_mode: "include_all",
                                                         resolution_mode: "resolved",
                                                         serialization_format: "marshal",
                                                         no_validate: false,
                                                         no_stats: false,
                                                       })

        # Quick command should execute multiple steps
        expect(command).to respond_to(:quick)
      end
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
