# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::PackagePath do
  describe "#initialize" do
    it "creates a path from string" do
      path = described_class.new("ModelRoot::Package1::Package2")
      expect(path.to_s).to eq("ModelRoot::Package1::Package2")
    end

    it "creates a path from array" do
      path = described_class.new(["ModelRoot", "Package1", "Package2"])
      expect(path.to_s).to eq("ModelRoot::Package1::Package2")
    end

    it "is frozen after initialization" do
      path = described_class.new("ModelRoot::Package1")
      expect(path).to be_frozen
    end

    it "normalizes empty segments" do
      path = described_class.new("ModelRoot::::Package1")
      expect(path.to_s).to eq("ModelRoot::Package1")
    end

    it "handles single segment" do
      path = described_class.new("ModelRoot")
      expect(path.to_s).to eq("ModelRoot")
    end
  end

  describe "#absolute?" do
    it "returns true for ModelRoot paths" do
      path = described_class.new("ModelRoot::Package1")
      expect(path.absolute?).to be true
    end

    it "returns false for relative paths" do
      path = described_class.new("Package1::Package2")
      expect(path.absolute?).to be false
    end

    it "returns false for empty path" do
      path = described_class.new("")
      expect(path.absolute?).to be false
    end
  end

  describe "#depth" do
    it "calculates correct depth for nested path" do
      path = described_class.new("ModelRoot::Package1::Package2")
      expect(path.depth).to eq(2)
    end

    it "returns 0 for ModelRoot" do
      path = described_class.new("ModelRoot")
      expect(path.depth).to eq(0)
    end

    it "returns 1 for single level" do
      path = described_class.new("ModelRoot::Package1")
      expect(path.depth).to eq(1)
    end

    it "returns correct depth for relative path" do
      path = described_class.new("Package1::Package2::Package3")
      expect(path.depth).to eq(2)
    end
  end

  describe "#parent" do
    it "returns parent path" do
      path = described_class.new("ModelRoot::Package1::Package2")
      parent = path.parent
      expect(parent.to_s).to eq("ModelRoot::Package1")
    end

    it "handles root path" do
      path = described_class.new("ModelRoot")
      parent = path.parent
      expect(parent).to be_nil
    end

    it "handles single segment relative path" do
      path = described_class.new("Package1")
      parent = path.parent
      expect(parent).to be_nil
    end

    it "returns correct parent for multi-level path" do
      path = described_class.new("ModelRoot::A::B::C")
      expect(path.parent.to_s).to eq("ModelRoot::A::B")
      expect(path.parent.parent.to_s).to eq("ModelRoot::A")
      expect(path.parent.parent.parent.to_s).to eq("ModelRoot")
      expect(path.parent.parent.parent.parent).to be_nil
    end
  end

  describe "#relative_to" do
    it "creates relative path" do
      base = described_class.new("ModelRoot::Package1")
      full = described_class.new("ModelRoot::Package1::Package2::Package3")
      relative = full.relative_to(base)
      expect(relative.to_s).to eq("Package2::Package3")
    end

    it "handles non-matching base" do
      base = described_class.new("ModelRoot::Other")
      full = described_class.new("ModelRoot::Package1::Package2")
      relative = full.relative_to(base)
      expect(relative.to_s).to eq("ModelRoot::Package1::Package2")
    end

    it "handles exact match" do
      base = described_class.new("ModelRoot::Package1")
      full = described_class.new("ModelRoot::Package1")
      relative = full.relative_to(base)
      expect(relative.to_s).to eq("")
    end

    it "handles base longer than full path" do
      base = described_class.new("ModelRoot::Package1::Package2")
      full = described_class.new("ModelRoot::Package1")
      relative = full.relative_to(base)
      expect(relative.to_s).to eq("ModelRoot::Package1")
    end
  end

  describe "#matches_glob?" do
    it "matches exact paths" do
      path = described_class.new("ModelRoot::Package1::Class1")
      expect(path.matches_glob?("ModelRoot::Package1::Class1")).to be true
    end

    it "does not match different paths" do
      path = described_class.new("ModelRoot::Package1::Class1")
      expect(path.matches_glob?("ModelRoot::Package2::Class1")).to be false
    end

    it "matches * wildcard" do
      path = described_class.new("ModelRoot::Package1::Class1")
      expect(path.matches_glob?("ModelRoot::*::Class1")).to be true
    end

    it "matches ** recursive wildcard" do
      path = described_class.new("ModelRoot::Package1::Sub::Class1")
      expect(path.matches_glob?("ModelRoot::**::Class1")).to be true
    end

    it "matches ** at end" do
      path = described_class.new("ModelRoot::Package1::Sub::Deep")
      expect(path.matches_glob?("ModelRoot::Package1::**")).to be true
    end

    it "matches * for single segment" do
      path = described_class.new("ModelRoot::AnyPackage::Class1")
      expect(path.matches_glob?("ModelRoot::*::Class1")).to be true
    end

    it "does not match * across multiple segments" do
      path = described_class.new("ModelRoot::Package1::Package2::Class1")
      expect(path.matches_glob?("ModelRoot::*::Class1")).to be false
    end

    it "matches complex glob patterns" do
      path = described_class.new("ModelRoot::Package1::Sub1::Sub2::Class1")
      expect(path.matches_glob?("ModelRoot::**::Class1")).to be true
      expect(path.matches_glob?("ModelRoot::Package1::**")).to be true
      expect(path.matches_glob?("ModelRoot::*::**::Class1")).to be true
    end
  end

  describe "#==" do
    it "returns true for equal paths" do
      path1 = described_class.new("ModelRoot::Package1")
      path2 = described_class.new("ModelRoot::Package1")
      expect(path1).to eq(path2)
    end

    it "returns false for different paths" do
      path1 = described_class.new("ModelRoot::Package1")
      path2 = described_class.new("ModelRoot::Package2")
      expect(path1).not_to eq(path2)
    end
  end

  describe "#hash" do
    it "returns same hash for equal paths" do
      path1 = described_class.new("ModelRoot::Package1")
      path2 = described_class.new("ModelRoot::Package1")
      expect(path1.hash).to eq(path2.hash)
    end

    it "can be used as hash key" do
      path1 = described_class.new("ModelRoot::Package1")
      path2 = described_class.new("ModelRoot::Package1")
      hash = { path1 => "value1" }
      expect(hash[path2]).to eq("value1")
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      path = described_class.new("ModelRoot::Package1::Package2")
      expect(path.to_s).to eq("ModelRoot::Package1::Package2")
    end

    it "returns empty string for empty path" do
      path = described_class.new("")
      expect(path.to_s).to eq("")
    end
  end
end
