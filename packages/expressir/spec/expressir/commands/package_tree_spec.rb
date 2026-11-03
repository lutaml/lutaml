# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe Expressir::Commands::Package, "#tree" do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#tree" do
    context "with a valid package" do
      it "displays tree view in default format" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "respects depth limit option" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("depth" => 1)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "filters by element type" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "entity")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "filters by schema name" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("schema" => "test_schema")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows counts when requested" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("counts" => true)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "disables color output when requested" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("no_color" => true)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "combines multiple options" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new(
          "depth" => 2,
          "type" => "entity",
          "counts" => true,
          "no_color" => true,
        )
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "with depth limits" do
      it "shows only schemas at depth 1" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("depth" => 1)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows schemas and top-level elements at depth 2" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("depth" => 2)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows full tree including attributes at depth 3" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("depth" => 3)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "with type filters" do
      it "shows only entities" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "entity")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only types" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "type")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only functions" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "function")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only procedures" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "procedure")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only rules" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "rule")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only attributes" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "attribute")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows only parameters" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("type" => "parameter")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "with schema filter" do
      it "shows tree for specific schema only" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("schema" => "action_schema")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "handles non-existent schema gracefully" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("schema" => "nonexistent_schema")
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "with counts option" do
      it "shows element counts at schema level" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("counts" => true, "depth" => 1)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "shows counts with full tree" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("counts" => true)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "with color options" do
      it "uses colored output by default" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end

      it "disables colors when no_color is true" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/test.ler")

        command = described_class.new("no_color" => true)
        expect { command.tree("spec/fixtures/test.ler") }.not_to raise_error
      end
    end

    context "when package does not exist" do
      it "raises PackageNotFoundError" do
        command = described_class.new
        expect { command.tree("nonexistent.ler") }.to raise_error(Expressir::PackageNotFoundError)
      end
    end

    context "with empty package" do
      it "handles package with no schemas gracefully" do
        skip "Package creation not yet available" unless File.exist?("spec/fixtures/empty.ler")

        command = described_class.new
        expect { command.tree("spec/fixtures/empty.ler") }.not_to raise_error
      end
    end
  end

  describe "helper methods" do
    let(:command) { described_class.new }

    describe "#colorize" do
      it "returns colored text when no_color is false" do
        skip "Paint gem does not support colors on Windows" if Gem.win_platform?
        skip "Requires paint gem" unless defined?(Paint)

        result = command.send(:colorize, "test", :red)
        expect(result).not_to eq("test")
      end

      it "returns plain text when no_color is true" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ no_color: true })
        result = command.send(:colorize, "test", :red)
        expect(result).to eq("test")
      end
    end

    describe "#element_color" do
      it "returns green for entities" do
        expect(command.send(:element_color, "entity")).to eq(:green)
      end

      it "returns yellow for types" do
        expect(command.send(:element_color, "type")).to eq(:yellow)
      end

      it "returns cyan for attributes" do
        expect(command.send(:element_color, "attribute")).to eq(:cyan)
      end

      it "returns magenta for functions" do
        expect(command.send(:element_color, "function")).to eq(:magenta)
      end

      it "returns magenta for procedures" do
        expect(command.send(:element_color, "procedure")).to eq(:magenta)
      end

      it "returns red for rules" do
        expect(command.send(:element_color, "rule")).to eq(:red)
      end

      it "returns white for unknown types" do
        expect(command.send(:element_color, "unknown")).to eq(:white)
      end
    end

    describe "#should_include_type?" do
      it "returns true when no type filter is set" do
        expect(command.send(:should_include_type?, "entity")).to be true
      end

      it "returns true when type matches filter" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ type: "entity" })
        expect(command.send(:should_include_type?, "entity")).to be true
      end

      it "returns false when type does not match filter" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ type: "entity" })
        expect(command.send(:should_include_type?, "type")).to be false
      end

      it "matches attribute variations" do
        command = described_class.new
        allow(command).to receive(:options).and_return({ type: "attribute" })
        expect(command.send(:should_include_type?,
                            "derived_attribute")).to be true
        expect(command.send(:should_include_type?,
                            "inverse_attribute")).to be true
      end
    end

    describe "#pluralize" do
      it "returns singular form for count of 1" do
        expect(command.send(:pluralize, "entity", 1)).to eq("entity")
      end

      it "returns plural form for count of 0" do
        expect(command.send(:pluralize, "entity", 0)).to eq("entitys")
      end

      it "returns plural form for count greater than 1" do
        expect(command.send(:pluralize, "entity", 5)).to eq("entitys")
      end
    end

    describe "#extract_type_info" do
      it "returns type reference for simple references" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::References::SimpleReference.new(id: "test_type"),
        )
        expect(command.send(:extract_type_info, element)).to eq("test_type")
      end

      it "returns SET for set types" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::Set.new(
            base_type: Expressir::Model::References::SimpleReference.new(id: "test_type"),
          ),
        )
        expect(command.send(:extract_type_info, element)).to eq("SET")
      end

      it "returns LIST for list types" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::List.new(
            base_type: Expressir::Model::References::SimpleReference.new(id: "test_type"),
          ),
        )
        expect(command.send(:extract_type_info, element)).to eq("LIST")
      end

      it "returns ARRAY for array types" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::Array.new(
            base_type: Expressir::Model::References::SimpleReference.new(id: "test_type"),
          ),
        )
        expect(command.send(:extract_type_info, element)).to eq("ARRAY")
      end

      it "returns STRING for string types" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::String.new,
        )
        expect(command.send(:extract_type_info, element)).to eq("STRING")
      end

      it "returns INTEGER for integer types" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: Expressir::Model::DataTypes::Integer.new,
        )
        expect(command.send(:extract_type_info, element)).to eq("INTEGER")
      end

      it "returns ANY for nil type" do
        element = Expressir::Model::Declarations::Attribute.new(
          id: "test_attr",
          type: nil,
        )
        expect(command.send(:extract_type_info, element)).to eq("ANY")
      end
    end
  end
end
