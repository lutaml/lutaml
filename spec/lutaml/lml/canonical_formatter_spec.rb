# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "lutaml/lml/cli"

RSpec.describe Lutaml::Formatter::Canonical do
  # Explicitly-assigned defaults that mean the same thing as absent
  # (the parser records `+x` as visibility public, for instance).
  def default_values
    {
      "visibility" => "public",
      "literal" => false,
      "is_derived" => false,
      "is_static" => false,
      "is_read_only" => false,
      "is_abstract" => false,
    }
  end

  def parse(source)
    Lutaml::Lml.parse_document(source)
  end

  def canonical(source)
    described_class.new(parse(source)).render
  end

  # Model comparison for the semantic law: default-valued keys are
  # equated with absence, the cardinality default [0..1] is equated
  # with an omitted cardinality, and the unbounded token * with n.
  def normalize(node)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        next if default_values.key?(key) && default_values[key] == value

        if key == "cardinality" && value.is_a?(Hash)
          next if value["min"] == "0" && value["max"] == "1"

          result[key] = value.merge("max" => unbounded(value["max"]))
          next
        end

        result[key] = normalize(value)
      end
    when Array
      node.map { |item| normalize(item) }
    else
      node
    end
  end

  def unbounded(max)
    max == "*" ? "n" : max
  end

  def model(source)
    normalize(parse(source).to_hash)
  end

  describe "corpus laws" do
    Dir[fixtures_path("rs3001/*.lml")].each do |path|
      it "canonicalizes #{File.basename(path)} idempotently and preserves the model" do
        source = File.read(path)
        once = canonical(source)

        expect(canonical(once)).to eq(once)
        expect(model(once)).to eq(model(source))
      end
    end

    it "keeps the vendored corpus canonical", :aggregate_failures do
      Dir[fixtures_path("rs3001/*.lml")].each do |path|
        source = File.read(path)

        expect(canonical(source)).to eq(source), "#{path} is not canonical"
      end
    end
  end

  describe "member order and layout" do
    it "renders fixed groups with declaration order inside a group" do
      source = <<~LML
        instances Z { }
        class B { }
        enum E { }
        class A { }
      LML

      expect(canonical(source)).to eq(<<~LML)
        class B {
        }

        class A {
        }

        enum E {
        }

        instances Z {
        }
      LML
    end

    it "packs the models wrapper and ends with one newline" do
      source = "models M { class A { attribute x, String } }"

      expect(canonical(source)).to eq(<<~LML)
        models M {
          class A {
            attribute x, String
          }
        }
      LML
    end

    it "emits no blank first or last body line" do
      expect(canonical("class A { }")).to eq("class A {\n}\n")
    end
  end

  describe "attribute forms" do
    it "uses the terse comma form for name and type only" do
      expect(canonical("class A { attribute x, String }"))
        .to include("attribute x, String")
    end

    it "uses the block form for cardinality and options" do
      source = <<~LML
        class A {
          attribute x, String {
            cardinality 0..n
            values { a, b }
            pattern /\\d+/
          }
        }
      LML

      expect(canonical(source)).to eq(<<~LML)
        class A {
          attribute x {
            type String
            cardinality 0..n
            values { a, b }
            pattern /\\d+/
          }
        }
      LML
    end

    it "omits the default cardinality [0..1]" do
      expect(canonical("class A { attribute x, String { cardinality 0..1 } }"))
        .to include("attribute x, String")
    end

    it "renders visibility as a symbol prefix only when non-public" do
      source = "class A { -x: String [0..1] }"

      expect(canonical(source)).to include("-x: String")
      expect(canonical("class A { attribute x, String }"))
        .not_to include("+x")
    end

    it "renders definitions in the line or block form" do
      line = canonical('class A { definition "one line" }')
      block = canonical("class A { definition { one\ntwo } }")

      expect(line).to include('definition "one line"')
      expect(block).to include("  definition {\n    one\n    two\n  }")
    end
  end

  describe "quoting and value semantics" do
    it "quotes non-word values and escapes quotes and backslashes" do
      source = 'instance R { name = "Raku \"kiln\" fired" note = "" retired = null }'

      expect(canonical(source)).to eq(<<~LML)
        instance R {
          name = "Raku \\"kiln\\" fired"

          note = ""

          retired = null
        }
      LML
    end

    it "keeps bare-word instance names quoted" do
      expect(canonical('instance "paris" Studio { }'))
        .to include('Studio "paris"')
    end
  end

  describe "comments" do
    it "preserves comment content and canonicalizes the kind" do
      source = <<~LML
        ** top
        *|multi
        line|*
        class A {
          ** inner
        }
      LML

      once = canonical(source)
      parsed = parse(once)

      expect(parsed.comments).to eq(%W[top multi\nline])
      expect(parsed.classes.first.comments).to eq(["inner"])
      expect(canonical(once)).to eq(once)
      expect(once).to include("** top")
      expect(once).to include("*|multi\nline|*")
    end
  end

  describe "model shapes preserved" do
    def expect_laws(source)
      once = canonical(source)

      expect(canonical(once)).to eq(once)
      expect(model(once)).to eq(model(source))
      once
    end

    it "keeps an attribute definition in the bare form" do
      output = expect_laws('class A { x: String { definition "d" } }')

      expect(output).to include("  x: String {\n    definition \"d\"\n  }")
    end

    it "quotes non-word attribute names in both the naked and typed forms" do
      naked = expect_laws('class A { "art code" { definition "d" } }')
      typed = expect_laws('class A { "CCT Number": String }')

      expect(naked).to include('"art code" {')
      expect(typed).to include('"CCT Number": String')
    end

    it "renders a parent class from parent_class" do
      expect(expect_laws("class A < Array { }")).to include("class A < Array {")
    end

    it "keeps direct enum member definitions direct" do
      output = expect_laws('enum E { warning { definition "w" } }')

      expect(output).to include("  warning {\n    definition \"w\"\n  }")
    end

    it "renders typed enum members as attributes" do
      output = expect_laws("enum E { addressClassProfile: CharacterString }")

      expect(output).to include("attribute addressClassProfile, CharacterString")
    end

    it "renders extended assignments with +=" do
      output = expect_laws('instance P { a += "x" }')

      expect(output).to include('a += "x"')
    end

    it "quotes collection names" do
      output = expect_laws('instances { collection "C" { } }')

      expect(output).to include('collection "C" {')
    end

    it "renders a comment-attribute of an instance as a comment" do
      output = expect_laws("instance X {\n  # note here\n  a = \"b\"\n}")

      expect(output).to include("# note here")
    end
  end

  describe "instance collections" do
    it "renders collections, references, and null distinctly" do
      source = <<~LML
        instances Glazes {
          GlazeFormula "blue_matte" {
            components = ["silica", "cobalt"]
            retired = null
          }

          CeramicTile "tile_002" {
            glaze = ref:(Glazes.blue_matte)
          }
        }
      LML

      expect(canonical(source)).to eq(<<~LML)
        instances Glazes {
          GlazeFormula "blue_matte" {
            components = ["silica", "cobalt"]

            retired = null
          }

          CeramicTile "tile_002" {
            glaze = ref:(Glazes.blue_matte)
          }
        }
      LML
    end
  end
end

RSpec.describe "lutaml format" do
  let(:noncanonical) { "class B { }\nclass A { }\n" }

  def run(*args)
    Lutaml::Cli::LmlCommands.start(args)
  end

  it "rewrites a file into canonical form" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "model.lml")
      File.write(path, noncanonical)

      run("format", path)

      expect(File.read(path)).to eq(<<~LML)
        class B {
        }

        class A {
        }
      LML
    end
  end

  it "reports a non-canonical file with a diff and exits 1 under --check" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "model.lml")
      File.write(path, noncanonical)

      output = StringIO.new
      original = $stdout
      $stdout = output
      begin
        expect { run("format", path, "--check") }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      ensure
        $stdout = original
      end

      expect(output.string).to include("--- #{path}", "+++ #{path} (canonical)")
      expect(output.string).to include("#{path} is not canonical")
      expect(File.read(path)).to eq(noncanonical)
    end
  end

  it "exits zero under --check when the file is already canonical" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "model.lml")
      File.write(path, noncanonical)
      run("format", path)

      expect { run("format", path, "--check") }.not_to raise_error
    end
  end

  describe "XML namespace and node kind (issue #49)" do
    let(:source) do
      <<~LML
        class Car {
          namespace "xyz" prefix "x"
          wheels Wheel[4] as :element
          vin: String as :attribute
        }
      LML
    end

    let(:formatted) { Lutaml::Formatter::Canonical.new(Lutaml::Lml.parse_document(source)).render }

    it "renders the class namespace and the as-role of each attribute" do
      expect(formatted).to include('namespace "xyz" prefix "x"')
        .and include("wheels: Wheel [4] as :element")
        .and include("vin: String as :attribute")
    end

    it "is a fixed point of parse and render" do
      reparsed = Lutaml::Lml.parse_document(formatted)
      expect(Lutaml::Formatter::Canonical.new(reparsed).render).to eq(formatted)
    end
  end
  describe "XML roles with attribute block options" do
    let(:source) do
      <<~LML
        class Car {
          attribute vin as :attribute {
            type String
            cardinality 1
            values { "A", "B" }
            pattern /[AB]/
            default = "A"
          }
        }
      LML
    end
    let(:document) { Lutaml::Lml.parse_document(source) }
    let(:formatted) { Lutaml::Formatter::Canonical.new(document).render }

    it "preserves the role and all block options when formatting" do
      original = document.classes.first.attributes.first
      reparsed = Lutaml::Lml.parse_document(formatted).classes.first.attributes.first
      expect(original.xml_role).to eq("attribute")
      expect(original.pattern).to eq("[AB]")
      expect(original.value_set).to eq(%w[A B])
      expect(reparsed.to_hash).to eq(original.to_hash)
      expect(Lutaml::Formatter::Canonical.new(Lutaml::Lml.parse_document(formatted)).render).to eq(formatted)
    end
  end
end
