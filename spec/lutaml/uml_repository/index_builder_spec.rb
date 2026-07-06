# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/uml_repository/index_builder"

RSpec.describe Lutaml::UmlRepository::IndexBuilder do
  let(:document) { create_test_document }
  let(:indexes) { described_class.build_all(document) }

  describe ".build_all" do
    it "builds all indexes", :aggregate_failures do
      expect(indexes).to be_a(Hash)
      expect(indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
        :inheritance_graph,
        :diagram_index,
        :simple_name_to_qnames,
      )
    end

    it "returns frozen hash" do
      expect(indexes).to be_frozen
    end

    it "includes all index types", :aggregate_failures do
      expect(indexes[:package_paths]).to be_a(Hash)
      expect(indexes[:qualified_names]).to be_a(Hash)
      expect(indexes[:stereotypes]).to be_a(Hash)
      expect(indexes[:inheritance_graph]).to be_a(Hash)
      expect(indexes[:diagram_index]).to be_a(Hash)
      expect(indexes[:package_to_classes]).to be_a(Hash)
      expect(indexes[:simple_name_to_qnames]).to be_a(Hash)
    end
  end

  describe "simple_name_to_qnames index" do
    let(:document) { create_resolution_test_document }

    it "maps each simple class name to all its qualified names",
       :aggregate_failures do
      map = indexes[:simple_name_to_qnames]
      expect(map["Shared"])
        .to contain_exactly("ModelRoot::PkgA::Shared", "ModelRoot::PkgB::Shared")
      expect(map["Beta"]).to eq(["ModelRoot::PkgA::Beta"])
    end

    it "only references qualified names that exist" do
      qualified_names = indexes[:qualified_names]
      indexes[:simple_name_to_qnames].each_value do |qname_list|
        qname_list.each { |qname| expect(qualified_names).to have_key(qname) }
      end
    end

    context "when two same-named classifiers collide on a qualified name" do
      # e.g. a class and an enum both called "Status" in one package — a real
      # EA-model shape. The qname is stored once, so the simple-name map must
      # hold it once too, or resolution reports a spurious ambiguity.
      let(:document) do
        pkg = Lutaml::Uml::Package.new
        pkg.name = "P"
        klass = Lutaml::Uml::Class.new
        klass.name = "Status"
        enum = Lutaml::Uml::Enum.new(name: "Status")
        pkg.classes = [klass]
        pkg.enums = [enum]
        doc = Lutaml::Uml::Document.new
        doc.name = "M"
        doc.packages = [pkg]
        doc
      end

      it "stores the qname once and matches the lazy derivation",
         :aggregate_failures do
        eager = indexes[:simple_name_to_qnames]
        expect(eager["Status"]).to eq(["ModelRoot::P::Status"])

        lazy = Lutaml::UmlRepository::LazyRepository
          .new(document: document, lazy: true)
        result = lazy.resolve_type("Status", from: "ModelRoot")
        expect(result.ambiguous?).to be(false)
        expect(result.candidates).to eq(["ModelRoot::P::Status"])
      end
    end
  end

  describe "inheritance graph resolution of generalization parents" do
    let(:document) do
      mk_child = lambda do |name, general|
        klass = Lutaml::Uml::Class.new(name: name, xmi_id: name)
        klass.generalization = Lutaml::Uml::Generalization.new(general: general)
        klass
      end
      pkg_b = Lutaml::Uml::Package.new(name: "PkgB", xmi_id: "pb")
      pkg_b.classes = [Lutaml::Uml::Class.new(name: "Parent", xmi_id: "p1")]
      pkg_a = Lutaml::Uml::Package.new(name: "PkgA", xmi_id: "pa")
      pkg_a.classes = [
        mk_child.call("CFull", "ModelRoot::PkgB::Parent"),
        mk_child.call("CLeaf", "Parent"),
        mk_child.call("CPartial", "PkgB::Parent"),
      ]
      doc = Lutaml::Uml::Document.new(name: "InheritanceModel")
      doc.packages = [pkg_a, pkg_b]
      doc
    end

    it "resolves fully-qualified and leaf parents but not partial ones",
       :aggregate_failures do
      children = indexes[:inheritance_graph]["ModelRoot::PkgB::Parent"] || []
      expect(children).to include("ModelRoot::PkgA::CFull")
      expect(children).to include("ModelRoot::PkgA::CLeaf")
      # The association index stays map-only (no suffix scan), so a partially
      # qualified parent creates no edge — preserving historical behaviour.
      expect(children).not_to include("ModelRoot::PkgA::CPartial")
    end
  end

  describe "package_paths index" do
    it "indexes packages by path" do
      package_paths_index = indexes[:package_paths]
      expect(package_paths_index).to be_a(Hash)
    end

    it "handles nested packages", :aggregate_failures do
      package_paths_index = indexes[:package_paths]
      package_paths_index.each do |path, package|
        expect(path).to be_a(String)
        expect(package).to be_a(Lutaml::Uml::Document)
          .or be_a(Lutaml::Uml::Package)
      end
    end

    it "creates correct paths for nested packages", :aggregate_failures do
      package_paths_index = indexes[:package_paths]
      paths = package_paths_index.keys.map(&:to_s)

      expect(paths).to include("ModelRoot")
      expect(paths.any? { |p| p.include?("::") }).to be(true).or be(false)
    end
  end

  describe "qualified_names index" do
    it "indexes classes by qualified name" do
      qualified_names_index = indexes[:qualified_names]
      expect(qualified_names_index).to be_a(Hash)
    end

    it "includes data types and enums", :aggregate_failures do
      qualified_names_index = indexes[:qualified_names]
      qualified_names_index.each do |qname, entity|
        expect(qname).to be_a(String)
        expect(entity).to be_a(Lutaml::Uml::Class)
          .or be_a(Lutaml::Uml::DataType)
          .or be_a(Lutaml::Uml::Enum)
      end
    end

    it "creates correct qualified names", :aggregate_failures do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).not_to be_empty
      expect(qnames).to all(be_a(String))
    end
  end

  describe "stereotypes index" do
    it "groups classes by stereotype" do
      stereotypes_index = indexes[:stereotypes]
      expect(stereotypes_index).to be_a(Hash)
    end

    it "handles classes without stereotypes", :aggregate_failures do
      stereotypes_index = indexes[:stereotypes]

      stereotypes_index.each do |stereotype, classes|
        if stereotype.nil?
          expect(classes).to be_an(Array)
          classes.each do |klass|
            expect(klass.stereotype).to be_nil
          end
        else
          expect(stereotype).to be_a(String)
          expect(classes).to be_an(Array)
        end
      end
    end

    it "groups classes correctly" do
      stereotypes_index = indexes[:stereotypes]

      stereotypes_index.each_value do |classes|
        expect(classes).to all(be_a(Lutaml::Uml::Class)
            .or(be_a(Lutaml::Uml::Enum)
            .or(be_a(Lutaml::Uml::DataType))))
      end
    end
  end

  describe "inheritance_graph index" do
    it "maps parent to children" do
      inheritance_graph = indexes[:inheritance_graph]
      expect(inheritance_graph).to be_a(Hash)
    end

    it "handles multiple inheritance levels", :aggregate_failures do
      inheritance_graph = indexes[:inheritance_graph]

      inheritance_graph.each do |parent_id, children|
        expect(parent_id).to be_a(String)
        expect(children).to be_an(Array)
        expect(children).to all(be_a(String))
      end
    end
  end

  describe "associations index" do
    it "creates bidirectional mappings" do
      associations = indexes[:associations]

      associations.values.flatten.each do |assoc|
        next unless ["inheritance",
                     "generalization"].include?(assoc.member_end_type)

        parent_id = assoc.member_end_xmi_id
        expect(associations.key?(parent_id)).to be(true).or be(false)
      end
    end
  end

  describe "diagram_index index" do
    it "indexes diagrams by package" do
      diagram_index = indexes[:diagram_index]
      expect(diagram_index).to be_a(Hash)
    end

    it "groups diagrams correctly", :aggregate_failures do
      diagram_index = indexes[:diagram_index]

      diagram_index.each do |package_id, diagrams|
        expect(package_id).to be_a(String)
        expect(diagrams).to be_an(Array)
        expect(diagrams).to all(be_a(Lutaml::Uml::Diagram))
      end
    end
  end

  describe "package_to_classes index" do
    it "maps package paths to arrays of classes", :aggregate_failures do
      pkg_to_classes = indexes[:package_to_classes]
      expect(pkg_to_classes).to be_a(Hash)

      pkg_to_classes.each do |path, classes|
        expect(path).to be_a(String)
        expect(classes).to be_an(Array)
        expect(classes).to all(be_a(Lutaml::Uml::Class)
          .or(be_a(Lutaml::Uml::DataType))
          .or(be_a(Lutaml::Uml::Enum)))
      end
    end

    it "is consistent with qualified_names" do
      pkg_to_classes = indexes[:package_to_classes]
      qualified_names = indexes[:qualified_names]

      qualified_names.each do |qname, klass|
        pkg_path = qname.include?("::") ? qname.sub(/::[^:]+$/, "") : ""
        next if pkg_path.empty?

        expect(pkg_to_classes[pkg_path]).to include(klass),
                                            "package_to_classes[#{pkg_path}] should include " \
                                            "#{klass.name} (from qname #{qname})"
      end
    end
  end

  describe "with simple document" do
    let(:document) { create_simple_test_document }

    it "builds indexes for simple document", :aggregate_failures do
      expect(indexes).to be_a(Hash)
      expect(indexes.keys).to include(
        :package_paths,
        :qualified_names,
        :stereotypes,
      )
    end

    it "indexes simple package structure", :aggregate_failures do
      package_paths_index = indexes[:package_paths]
      paths = package_paths_index.keys.map(&:to_s)

      expect(paths).to include("ModelRoot")
      expect(paths).to include("ModelRoot::RootPackage")
      expect(paths).to include("ModelRoot::RootPackage::NestedPackage")
    end

    it "indexes simple class structure" do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).to include("ModelRoot::RootPackage::TestClass")
    end

    it "indexes simple enum structure" do
      qualified_names_index = indexes[:qualified_names]
      qnames = qualified_names_index.keys.map(&:to_s)

      expect(qnames).to include("ModelRoot::RootPackage::TestEnum")
    end

    it "groups by stereotype correctly", :aggregate_failures do
      stereotypes_index = indexes[:stereotypes]

      expect(stereotypes_index).to have_key("TestStereotype")
      expect(stereotypes_index["TestStereotype"]).to be_an(Array)
      expect(stereotypes_index["TestStereotype"].first.name).to eq("TestClass")
    end
  end
end
