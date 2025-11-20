# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/qea/models/ea_script"

RSpec.describe Lutaml::Qea::Models::EaScript do
  describe ".primary_key_column" do
    it "returns :script_id" do
      expect(described_class.primary_key_column).to eq(:script_id)
    end
  end

  describe ".table_name" do
    it "returns 't_script'" do
      expect(described_class.table_name).to eq("t_script")
    end
  end

  describe "#primary_key" do
    it "returns script_id value" do
      script = described_class.new(script_id: 123)
      expect(script.primary_key).to eq(123)
    end
  end

  describe "attribute access" do
    it "allows reading and writing script_id" do
      script = described_class.new(script_id: 456)
      expect(script.script_id).to eq(456)
    end

    it "allows reading and writing script_category" do
      script = described_class.new(script_category: "ScriptDebugging")
      expect(script.script_category).to eq("ScriptDebugging")
    end

    it "allows reading and writing script_name" do
      script = described_class.new(script_name: "MyScript")
      expect(script.script_name).to eq("MyScript")
    end

    it "allows reading and writing script_author" do
      script = described_class.new(script_author: "John Doe")
      expect(script.script_author).to eq("John Doe")
    end

    it "allows reading and writing notes" do
      script = described_class.new(notes: "Important notes")
      expect(script.notes).to eq("Important notes")
    end

    it "allows reading and writing script" do
      script = described_class.new(script: "console.log('test');")
      expect(script.script).to eq("console.log('test');")
    end
  end

  describe "aliases" do
    it "provides id alias for script_id" do
      script = described_class.new(script_id: 789)
      expect(script.id).to eq(789)
    end

    it "provides name alias for script_name" do
      script = described_class.new(script_name: "TestScript")
      expect(script.name).to eq("TestScript")
    end

    it "provides category alias for script_category" do
      script = described_class.new(script_category: "Debugging")
      expect(script.category).to eq("Debugging")
    end

    it "provides author alias for script_author" do
      script = described_class.new(script_author: "Jane Doe")
      expect(script.author).to eq("Jane Doe")
    end
  end

  describe "#debugging_script?" do
    it "returns true when script_category is ScriptDebugging" do
      script = described_class.new(script_category: "ScriptDebugging")
      expect(script).to be_debugging_script
    end

    it "returns false when script_category is not ScriptDebugging" do
      script = described_class.new(script_category: "Other")
      expect(script).not_to be_debugging_script
    end

    it "returns false when script_category is nil" do
      script = described_class.new(script_category: nil)
      expect(script).not_to be_debugging_script
    end
  end

  describe "#has_content?" do
    it "returns true when script is present" do
      script = described_class.new(script: "function test() {}")
      expect(script).to have_content
    end

    it "returns false when script is nil" do
      script = described_class.new(script: nil)
      expect(script).not_to have_content
    end

    it "returns false when script is empty" do
      script = described_class.new(script: "")
      expect(script).not_to have_content
    end
  end

  describe "#has_notes?" do
    it "returns true when notes is present" do
      script = described_class.new(notes: "Some notes")
      expect(script).to have_notes
    end

    it "returns false when notes is nil" do
      script = described_class.new(notes: nil)
      expect(script).not_to have_notes
    end

    it "returns false when notes is empty" do
      script = described_class.new(notes: "")
      expect(script).not_to have_notes
    end
  end

  describe ".from_db_row" do
    it "creates instance from database row" do
      row = {
        "ScriptID" => 123,
        "ScriptCategory" => "ScriptDebugging",
        "ScriptName" => "TestScript",
        "ScriptAuthor" => "Author Name",
        "Notes" => "Script notes",
        "Script" => "alert('test');",
      }

      script = described_class.from_db_row(row)

      expect(script.script_id).to eq(123)
      expect(script.script_category).to eq("ScriptDebugging")
      expect(script.script_name).to eq("TestScript")
      expect(script.script_author).to eq("Author Name")
      expect(script.notes).to eq("Script notes")
      expect(script.script).to eq("alert('test');")
    end

    it "returns nil when row is nil" do
      expect(described_class.from_db_row(nil)).to be_nil
    end
  end

  describe "inheritance" do
    it "inherits from BaseModel" do
      expect(described_class).to be < Lutaml::Qea::Models::BaseModel
    end
  end
end