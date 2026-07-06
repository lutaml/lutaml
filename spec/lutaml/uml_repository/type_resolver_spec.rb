# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/type_resolver"

RSpec.describe Lutaml::UmlRepository::TypeResolver do
  let(:document) { create_resolution_test_document }
  let(:indexes) { Lutaml::UmlRepository::IndexBuilder.build_all(document) }
  let(:qnames) { indexes[:qualified_names] }
  let(:simple_map) { indexes[:simple_name_to_qnames] }

  def resolve(type, package_path, simple_name_to_qnames: simple_map)
    described_class.resolve(type: type, package_path: package_path,
                            qualified_names: qnames,
                            simple_name_to_qnames: simple_name_to_qnames)
  end

  describe ".resolve" do
    it "resolves an already-qualified type to itself", :aggregate_failures do
      result = resolve("ModelRoot::PkgB::Gamma", "ModelRoot::PkgA")
      expect(result.qualified_name).to eq("ModelRoot::PkgB::Gamma")
      expect(result.classifier.name).to eq("Gamma")
      expect(result.resolved?).to be(true)
      expect(result.ambiguous?).to be(false)
      expect(result.primitive?).to be(false)
      expect(result.candidates).to eq(["ModelRoot::PkgB::Gamma"])
    end

    it "prefers a same-package match", :aggregate_failures do
      result = resolve("Beta", "ModelRoot::PkgA")
      expect(result.qualified_name).to eq("ModelRoot::PkgA::Beta")
      expect(result.classifier.name).to eq("Beta")
      expect(result.ambiguous?).to be(false)
    end

    it "lets a same-package match win over a globally ambiguous name" do
      result = resolve("Shared", "ModelRoot::PkgA")
      expect(result.qualified_name).to eq("ModelRoot::PkgA::Shared")
      expect(result.ambiguous?).to be(false)
    end

    it "resolves a unique simple name across packages", :aggregate_failures do
      result = resolve("Gamma", "ModelRoot::PkgA")
      expect(result.qualified_name).to eq("ModelRoot::PkgB::Gamma")
      expect(result.ambiguous?).to be(false)
    end

    it "resolves a partially-qualified reference via the suffix scan" do
      # "PkgA::Beta" is not a leaf simple name, so it misses the prebuilt map
      # and must fall back to the qualified-name suffix scan.
      expect(resolve("PkgA::Beta", "ModelRoot::PkgC").qualified_name)
        .to eq("ModelRoot::PkgA::Beta")
    end

    it "flags an ambiguous simple name and lists all candidates",
       :aggregate_failures do
      result = resolve("Shared", "ModelRoot::PkgC")
      expect(result.ambiguous?).to be(true)
      expect(result.candidates)
        .to contain_exactly("ModelRoot::PkgA::Shared", "ModelRoot::PkgB::Shared")
      expect(result.qualified_name).to eq(result.candidates.first)
      expect(result.resolved?).to be(true)
    end

    it "treats primitives as resolved without a classifier",
       :aggregate_failures do
      result = resolve("String", "ModelRoot::PkgA")
      expect(result.primitive?).to be(true)
      expect(result.resolved?).to be(true)
      expect(result.classifier).to be_nil
    end

    it "returns an unresolved result for an unknown type",
       :aggregate_failures do
      result = resolve("DoesNotExist", "ModelRoot::PkgA")
      expect(result.resolved?).to be(false)
      expect(result.qualified_name).to be_nil
      expect(result.classifier).to be_nil
      expect(result.candidates).to be_empty
    end

    it "does not strip cardinality or other suffixes" do
      expect(resolve("Beta[0..1]", "ModelRoot::PkgA").resolved?).to be(false)
    end

    it "is deterministic across repeated calls", :aggregate_failures do
      first = resolve("Shared", "ModelRoot::PkgC")
      second = resolve("Shared", "ModelRoot::PkgC")
      expect(first.qualified_name).to eq(second.qualified_name)
      expect(first.candidates).to eq(second.candidates)
    end

    context "with duplicate qnames in a stored simple-name index" do
      # A .lur exported before the collision guard can hold the same qname
      # twice (two same-named classifiers in one package). One qualified name
      # is one candidate — not a spurious ambiguity.
      it "dedupes candidates before deciding ambiguity", :aggregate_failures do
        dup_map = { "Gamma" => ["ModelRoot::PkgB::Gamma",
                                "ModelRoot::PkgB::Gamma"] }
        result = resolve("Gamma", "ModelRoot::PkgA",
                         simple_name_to_qnames: dup_map)
        expect(result.qualified_name).to eq("ModelRoot::PkgB::Gamma")
        expect(result.ambiguous?).to be(false)
        expect(result.candidates).to eq(["ModelRoot::PkgB::Gamma"])
      end
    end

    context "with a prebuilt index (suffix scan gated on '::')" do
      # The leaf-keyed map cannot answer "PkgB::Gamma", and a map miss on a
      # bare name is definitive (every classifier name is a key) — so the
      # suffix scan must run exactly when the type contains "::".
      it "still scans qualified names by suffix", :aggregate_failures do
        result = resolve("PkgB::Gamma", "ModelRoot::PkgA")
        expect(result.qualified_name).to eq("ModelRoot::PkgB::Gamma")
        expect(result.resolved?).to be(true)
      end

      it "never falls back to the scan for a bare name missing from the map" do
        # "Gamma" is resolvable by suffix scan, so only an authoritative map
        # miss — not a coincidental scan miss — explains an unresolved result.
        incomplete = { "Beta" => ["ModelRoot::PkgA::Beta"] }
        result = resolve("Gamma", "ModelRoot::PkgA",
                         simple_name_to_qnames: incomplete)
        expect(result.resolved?).to be(false)
      end
    end

    context "without a simple-name index (legacy .lur packages)" do
      it "rebuilds candidates from qualified_names" do
        result = resolve("Gamma", "ModelRoot::PkgA", simple_name_to_qnames: nil)
        expect(result.qualified_name).to eq("ModelRoot::PkgB::Gamma")
      end

      it "resolves ambiguity identically to the prebuilt index",
         :aggregate_failures do
        legacy = resolve("Shared", "ModelRoot::PkgC", simple_name_to_qnames: nil)
        indexed = resolve("Shared", "ModelRoot::PkgC")
        expect(legacy.qualified_name).to eq(indexed.qualified_name)
        expect(legacy.candidates).to eq(indexed.candidates)
        expect(legacy.ambiguous?).to be(true)
      end
    end
  end
end
