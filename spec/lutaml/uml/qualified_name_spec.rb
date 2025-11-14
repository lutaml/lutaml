# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Uml::QualifiedName do
  describe "#initialize" do
    it "creates a qualified name from string" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.to_s).to eq("Package1::Package2::ClassName")
    end

    it "creates a qualified name from array" do
      qname = described_class.new(["Package1", "Package2", "ClassName"])
      expect(qname.to_s).to eq("Package1::Package2::ClassName")
    end

    it "is frozen after initialization" do
      qname = described_class.new("Package1::ClassName")
      expect(qname).to be_frozen
    end

    it "normalizes empty segments" do
      qname = described_class.new("Package1::::ClassName")
      expect(qname.to_s).to eq("Package1::ClassName")
    end

    it "handles single segment" do
      qname = described_class.new("ClassName")
      expect(qname.to_s).to eq("ClassName")
    end
  end

  describe "#class_name" do
    it "returns the class name portion" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.class_name).to eq("ClassName")
    end

    it "returns class name for unqualified name" do
      qname = described_class.new("ClassName")
      expect(qname.class_name).to eq("ClassName")
    end

    it "returns empty string for empty qualified name" do
      qname = described_class.new("")
      expect(qname.class_name).to eq("")
    end
  end

  describe "#package_path" do
    it "returns PackagePath for packages" do
      qname = described_class.new("Package1::Package2::ClassName")
      path = qname.package_path
      expect(path).to be_a(Lutaml::Uml::PackagePath)
      expect(path.to_s).to eq("Package1::Package2")
    end

    it "returns empty PackagePath for unqualified name" do
      qname = described_class.new("ClassName")
      path = qname.package_path
      expect(path).to be_a(Lutaml::Uml::PackagePath)
      expect(path.to_s).to eq("")
    end

    it "returns empty PackagePath for empty qualified name" do
      qname = described_class.new("")
      path = qname.package_path
      expect(path).to be_a(Lutaml::Uml::PackagePath)
      expect(path.to_s).to eq("")
    end
  end

  describe "#qualified?" do
    it "returns true for qualified names" do
      qname = described_class.new("Package1::ClassName")
      expect(qname.qualified?).to be true
    end

    it "returns false for unqualified names" do
      qname = described_class.new("ClassName")
      expect(qname.qualified?).to be false
    end

    it "returns false for empty name" do
      qname = described_class.new("")
      expect(qname.qualified?).to be false
    end
  end

  describe "#matches_glob?" do
    it "matches exact qualified names" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.matches_glob?("Package1::Package2::ClassName")).to be true
    end

    it "does not match different qualified names" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.matches_glob?("Package1::Package3::ClassName")).to be false
    end

    it "matches * wildcard in package" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.matches_glob?("Package1::*::ClassName")).to be true
    end

    it "matches ** recursive wildcard" do
      qname = described_class.new("Package1::Package2::Sub::ClassName")
      expect(qname.matches_glob?("Package1::**::ClassName")).to be true
    end

    it "matches * wildcard in class name" do
      qname = described_class.new("Package1::ClassName")
      expect(qname.matches_glob?("Package1::Class*")).to be true
    end

    it "matches complex glob patterns" do
      qname = described_class.new("Package1::Sub1::Sub2::ClassName")
      expect(qname.matches_glob?("Package1::**::ClassName")).to be true
      expect(qname.matches_glob?("Package1::*::**")).to be true
      expect(qname.matches_glob?("**::ClassName")).to be true
    end
  end

  describe "#==" do
    it "returns true for equal qualified names" do
      qname1 = described_class.new("Package1::ClassName")
      qname2 = described_class.new("Package1::ClassName")
      expect(qname1).to eq(qname2)
    end

    it "returns false for different qualified names" do
      qname1 = described_class.new("Package1::ClassName")
      qname2 = described_class.new("Package2::ClassName")
      expect(qname1).not_to eq(qname2)
    end
  end

  describe "#hash" do
    it "returns same hash for equal qualified names" do
      qname1 = described_class.new("Package1::ClassName")
      qname2 = described_class.new("Package1::ClassName")
      expect(qname1.hash).to eq(qname2.hash)
    end

    it "can be used as hash key" do
      qname1 = described_class.new("Package1::ClassName")
      qname2 = described_class.new("Package1::ClassName")
      hash = { qname1 => "value1" }
      expect(hash[qname2]).to eq("value1")
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      qname = described_class.new("Package1::Package2::ClassName")
      expect(qname.to_s).to eq("Package1::Package2::ClassName")
    end

    it "returns empty string for empty qualified name" do
      qname = described_class.new("")
      expect(qname.to_s).to eq("")
    end
  end

  describe "#with_package" do
    it "creates new qualified name with different package" do
      qname = described_class.new("Package1::ClassName")
      new_path = Lutaml::Uml::PackagePath.new("Package2::Sub")
      new_qname = qname.with_package(new_path)
      expect(new_qname.to_s).to eq("Package2::Sub::ClassName")
    end

    it "preserves class name" do
      qname = described_class.new("Package1::ClassName")
      new_path = Lutaml::Uml::PackagePath.new("NewPackage")
      new_qname = qname.with_package(new_path)
      expect(new_qname.class_name).to eq("ClassName")
    end

    it "handles empty package path" do
      qname = described_class.new("Package1::ClassName")
      new_path = Lutaml::Uml::PackagePath.new("")
      new_qname = qname.with_package(new_path)
      expect(new_qname.to_s).to eq("ClassName")
    end
  end
end
