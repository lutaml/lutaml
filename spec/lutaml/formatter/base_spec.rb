# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Formatter::Base do
  describe "FORMAT_HANDLERS" do
    it "is a Hash" do
      expect(described_class::FORMAT_HANDLERS).to be_a(Hash)
    end

    it "maps every node type to a handler method" do
      aggregate_failures do
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::TopElementAttribute]).to eq(:format_attribute)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::Operation]).to eq(:format_operation)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::Association]).to eq(:format_relationship)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::Document]).to eq(:format_document)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::DataType]).to eq(:format_class)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::UmlClass]).to eq(:format_class)
        expect(described_class::FORMAT_HANDLERS[Lutaml::Lml::Enum]).to eq(:format_class)
      end
    end
  end

  describe "formatter registry" do
    let!(:registered_class) do
      stub_const("Lutaml::Formatter::Sample", Class.new(described_class))
    end

    after { Lutaml::Formatter.all.delete(registered_class) }

    it "registers subclasses in Formatter.all" do
      expect(Lutaml::Formatter.all).to include(registered_class)
    end

    it "returns the downcased last segment of the class name" do
      expect(registered_class.formatter_name).to eq(:sample)
    end

    it "does not shadow Class#name" do
      expect(registered_class.name).to eq("Lutaml::Formatter::Sample")
    end

    it "finds a formatter by name" do
      expect(Lutaml::Formatter.find_by_name("sample")).to eq(registered_class)
    end

    it "no longer ships the graphviz formatter (lives in lutaml-graphviz)" do
      expect(Lutaml::Formatter.constants).not_to include(:Graphviz)
    end
  end

  describe "#format dispatch" do
    # A concrete subclass that records which format_* method ran, instead
    # of mocking the dispatch target. Asserts on actual returned values,
    # not on method call expectations.
    let(:recorder_class) do
      Class.new(described_class) do
        def format_attribute(_node) = "attr:FORMATTED"
        def format_operation(_node) = "op:FORMATTED"
        def format_relationship(_node) = "rel:FORMATTED"
        def format_class(_node) = "class:FORMATTED"
        def format_document(_node) = "doc:FORMATTED"
      end
    end
    let(:formatter) { recorder_class.new }

    it "dispatches Document to format_document" do
      expect(formatter.format(Lutaml::Lml::Document.new)).to eq("doc:FORMATTED")
    end

    it "dispatches TopElementAttribute to format_attribute" do
      expect(formatter.format(Lutaml::Lml::TopElementAttribute.new)).to eq("attr:FORMATTED")
    end

    it "dispatches UmlClass to format_class" do
      expect(formatter.format(Lutaml::Lml::UmlClass.new)).to eq("class:FORMATTED")
    end

    it "dispatches Enum to format_class" do
      expect(formatter.format(Lutaml::Lml::Enum.new)).to eq("class:FORMATTED")
    end

    it "dispatches DataType to format_class" do
      expect(formatter.format(Lutaml::Lml::DataType.new)).to eq("class:FORMATTED")
    end

    it "dispatches Association to format_relationship" do
      expect(formatter.format(Lutaml::Lml::Association.new)).to eq("rel:FORMATTED")
    end

    it "dispatches Operation to format_operation" do
      expect(formatter.format(Lutaml::Lml::Operation.new)).to eq("op:FORMATTED")
    end

    it "raises for unknown node types" do
      unknown = Struct.new(:unused).new("anything")
      expect { formatter.format(unknown) }
        .to raise_error(Lutaml::Lml::Error, /no format handler/)
    end
  end

  describe "abstract methods" do
    let(:formatter) { described_class.new }

    it "raises NotImplementedError for format_attribute" do
      expect { formatter.format_attribute(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for format_operation" do
      expect { formatter.format_operation(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for format_relationship" do
      expect { formatter.format_relationship(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for format_class" do
      expect { formatter.format_class(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for format_document" do
      expect { formatter.format_document(nil) }.to raise_error(NotImplementedError)
    end
  end

  describe "#type=" do
    let(:formatter) { described_class.new }

    it "sets type as a downcased symbol" do
      formatter.type = "PNG"
      expect(formatter.type).to eq(:png)
    end

    it "strips whitespace" do
      formatter.type = " svg "
      expect(formatter.type).to eq(:svg)
    end
  end
end
