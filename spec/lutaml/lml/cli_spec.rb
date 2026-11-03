# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "tempfile"
require "lutaml/lml/cli"

# The gem writes YAML with Document#to_yaml and reads it back through the
# `-i yaml` input path. A document the gem produced itself has to survive that
# trip, so this drives the real Thor command rather than the parser underneath.
#
# `generate` is the command under test for the round-trip because it exercises
# the full parse-render path; `validate` covers the same input-format handling
# without rendering.
RSpec.describe Lutaml::Cli::LmlCommands do
  def write_yaml(fixture, dir)
    doc = Lutaml::Lml::Pipeline.call(File.new(fixtures_path(fixture)))
    path = File.join(dir, "#{File.basename(fixture, '.lml')}.yaml")
    File.write(path, doc.to_yaml)
    path
  end

  def find_attribute(instance, name)
    return nil unless instance

    Array(instance.attributes).each do |attr|
      return attr if attr.name == name

      Array(attr.instances).each do |nested|
        found = find_attribute(nested, name)
        return found if found
      end
    end
    find_attribute(instance.instance, name)
  end

  def generate(path, dir)
    described_class.start(
      ["generate", "-i", "yaml", "-o", File.join(dir, "out.dot"), path],
    )
  end

  # The defect is CollectionTrueMissingError raised out of the YAML reload,
  # before anything is rendered. Reaching Graphviz therefore proves the reload
  # worked, and Graphviz shells out to `dot`, which CI runners do not have.
  # So a missing binary at the render step is a pass, and any other error
  # still fails the example.
  def reload_through_cli(path, dir)
    generate(path, dir)
    :rendered
  rescue Errno::ENOENT => e
    raise unless e.message.include?("dot")

    :reached_renderer
  end

  describe "generate -i yaml" do
    # data_s102_check.lml carries `prerequisites = [ "S102_Dev1009" ]`, a list
    # literal. Before this change the reload raised CollectionTrueMissingError
    # straight out of the command.
    it "reads back YAML it wrote from a document with a list-valued attribute" do
      Dir.mktmpdir do |dir|
        path = write_yaml("lml/data_s102_check.lml", dir)

        expect(%i[rendered reached_renderer])
          .to include(reload_through_cli(path, dir))
      end
    end

    it "reads back YAML it wrote from a document with a map-valued attribute" do
      Dir.mktmpdir do |dir|
        path = write_yaml("mixed_lml/instances.lml", dir)

        expect(%i[rendered reached_renderer])
          .to include(reload_through_cli(path, dir))
      end
    end

    # The two examples above prove the command completes. They cannot prove the
    # list came back, because these fixtures are instance data and the graphviz
    # formatter only draws classes - the .dot it writes is empty boilerplate
    # either way. So assert the values through the handler the command actually
    # dispatches to for `-i yaml`, which is where the crash used to happen.
    it "recovers the list values through the handler generate dispatches to" do
      Dir.mktmpdir do |dir|
        path = write_yaml("lml/data_s102_check.lml", dir)

        doc = described_class::PARSE_HANDLERS["yaml"].call(Pathname.new(path))

        expect(find_attribute(doc.instance, "prerequisites").value)
          .to eq(["S102_Dev1009"])
      end
    end
  end

  describe "generate without the lutaml-graphviz gem" do
    before do
      allow_any_instance_of(described_class)
        .to receive(:require).with("lutaml/graphviz").and_raise(LoadError)
    end

    it "fails with install guidance instead of a LoadError" do
      Dir.mktmpdir do |dir|
        path = write_yaml("lml/data_s102_check.lml", dir)

        expect { generate(path, dir) }
          .to output(/requires the lutaml-graphviz gem/).to_stderr
          .and raise_error(SystemExit)
      end
    end

    it "still lets non-rendering commands run" do
      expect { described_class.start(["validate", fixtures_path("lml/data_s102_check.lml")]) }
        .not_to raise_error
    end
  end

  describe "PARSE_HANDLERS exp" do
    it "points at expressir when it is not installed" do
      handler = described_class::PARSE_HANDLERS["exp"]
      allow(handler.binding.receiver).to receive(:require).and_call_original
      allow(handler.binding.receiver).to receive(:require).with("expressir").and_raise(LoadError)

      expect { handler.call(Pathname.new("x.exp")) }
        .to raise_error(Thor::Error, /requires the expressir gem/)
    end
  end

  describe "validate" do
    def run_validate(*args)
      described_class.start(["validate", *args])
    end

    it "accepts a valid file with the default input format" do
      file = Tempfile.new(%w[model .lml])
      begin
        file.write('models Test { class Foo {} }')
        file.close

        expect { run_validate(file.path) }.not_to raise_error
      ensure
        file.unlink
      end
    end

    it "reads a YAML file when given -i yaml" do
      Dir.mktmpdir do |dir|
        path = write_yaml("lml/data_s102_check.lml", dir)

        expect { run_validate("-i", "yaml", path) }.not_to raise_error
      end
    end

    it "rejects a YAML file when the input format is left as lutaml" do
      Dir.mktmpdir do |dir|
        path = write_yaml("lml/data_s102_check.lml", dir)

        expect { run_validate(path) }.to raise_error(SystemExit)
      end
    end

    it "reports a parse failure and exits nonzero" do
      file = Tempfile.new(%w[model .lml])
      begin
        file.write("models Test { class Foo {")
        file.close

        expect { run_validate(file.path) }
          .to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      ensure
        file.unlink
      end
    end
  end

  describe "generate binary output through the CLI file path" do
    it "writes a PDF that re-parses through the CLI write path" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "models.lml")
        File.write(src, "models C { class Kiln { attribute program, String } }")
        out = File.join(dir, "kiln.pdf")

        described_class.start(
          ["generate", src, "--layout", "elk", "-t", "pdf", "-o", out],
        )

        expect(File.binread(out)).to start_with("%PDF-1.")
        require "pdfrb"
        expect(Pdfrb::Validator.validate(Pdfrb.open(out))).to be_empty
      end
    end
  end

  describe "compile --schema" do
    def run_compile(*args)
      described_class.start(["compile", *args])
    end

    it "reports a clear error when the input is a directory" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "models.lml"), "models C { class Kiln {} }")

        expect { run_compile(dir) }
          .to output("Expected a file, got directory: #{dir}\n").to_stderr
          .and raise_error(SystemExit)
      end
    end

    it "emits one JSON Schema per compiled model into a directory" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "models.lml")
        File.write(src, <<~LML)
          models Widgets {
            class Widget {
              attribute name, String
            }
            class Gadget {
              attribute label, String
            }
          }
        LML
        out = File.join(dir, "schemas")
        Dir.mkdir(out)

        run_compile(src, "--schema", "json", "--namespace", "CliSchemaA", "-o", out)

        expect(File).to exist(File.join(out, "widget.json"))
        expect(File).to exist(File.join(out, "gadget.json"))
        parsed = JSON.parse(File.read(File.join(out, "widget.json")))
        expect(parsed["$ref"]).to eq("#/$defs/CliSchemaA_Widget")
        expect(parsed["$defs"]).to have_key("CliSchemaA_Widget")
      end
    end

    it "writes a single YAML Schema document to a file" do
      Dir.mktmpdir do |dir|
        out = File.join(dir, "kiln.schema.yaml")

        run_compile(fixtures_path("rs3001/14_require_models.lml"),
                    "--schema", "yaml", "--namespace", "CliSchemaB", "-o", out)

        content = File.read(out)
        expect(content).to start_with("%YAML 1.1")
        expect(content).to include("CliSchemaB_Kiln")
      end
    end

    it "emits one multi-root document for all models when -o is a file" do
      Dir.mktmpdir do |dir|
        src = File.join(dir, "models.lml")
        File.write(src, <<~LML)
          models Widgets {
            class Widget { attribute name, String }
            class Gadget { attribute label, String }
          }
        LML
        out = File.join(dir, "widgets.schema.json")

        run_compile = -> { described_class.start(["compile", src, "--schema", "json", "--namespace", "CliSchemaD", "-o", out]) }
        expect { run_compile.call }.not_to raise_error
        parsed = JSON.parse(File.read(out))
        expect(parsed).not_to have_key("$ref")
        expect(parsed["$defs"]).to include("CliSchemaD_Widget", "CliSchemaD_Gadget")
      end
    end

    it "prints schema documents to stdout when no output path is given" do
      src = File.join(Dir.mktmpdir, "models.lml")
      File.write(src, "models C { class Kiln { attribute program, String } }")

      expect { run_compile(src, "--schema", "json", "--namespace", "CliSchemaC") }
        .to output(/CliSchemaC_Kiln/).to_stdout
    end
  end
end
