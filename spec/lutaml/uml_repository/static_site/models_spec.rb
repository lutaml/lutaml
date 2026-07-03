# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaCardinality do
  describe ".from_uml" do
    it "returns nil for nil input" do
      expect(described_class.from_uml(nil)).to be_nil
    end

    it "builds SpaCardinality from UML cardinality" do
      uml_card = Lutaml::Uml::Cardinality.new(min: "0", max: "*")
      result = described_class.from_uml(uml_card)

      expect(result).to be_a(described_class)
      expect(result.min).to eq("0")
      expect(result.max).to eq("*")
    end

    it "round-trips through JSON" do
      uml_card = Lutaml::Uml::Cardinality.new(min: "1", max: "1")
      result = described_class.from_uml(uml_card)
      parsed = described_class.from_json(result.to_json)

      expect(parsed.min).to eq("1")
      expect(parsed.max).to eq("1")
    end
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaAttribute do
  describe ".from_uml" do
    it "builds SpaAttribute from UML attribute" do
      uml_attr = Lutaml::Uml::TopElementAttribute.new(
        name: "testAttr", type: "String",
        visibility: "public",
        definition: "A test attr"
      )
      owner = Lutaml::Uml::Class.new(name: "TestClass", xmi_id: "cls_1")
      id_gen = Lutaml::UmlRepository::StaticSite::IdGenerator.new

      result = described_class.from_uml(
        uml_attr, owner,
        id_generator: id_gen,
        definition: "A test attr",
        stereotypes: []
      )

      expect(result).to be_a(described_class)
      expect(result.name).to eq("testAttr")
      expect(result.type).to eq("String")
      expect(result.owner_name).to eq("TestClass")
      expect(result.cardinality).to be_nil
    end

    it "round-trips through JSON" do
      uml_attr = Lutaml::Uml::TopElementAttribute.new(
        name: "id", type: "Integer",
        visibility: "private",
        is_static: true, is_read_only: true,
        default: "0"
      )
      owner = Lutaml::Uml::Class.new(name: "Widget", xmi_id: "cls_2")
      id_gen = Lutaml::UmlRepository::StaticSite::IdGenerator.new

      result = described_class.from_uml(
        uml_attr, owner,
        id_generator: id_gen,
        definition: nil,
        stereotypes: ["PK"]
      )

      parsed = described_class.from_json(result.to_json)
      expect(parsed.name).to eq("id")
      expect(parsed.is_static).to be true
      expect(parsed.is_read_only).to be true
      expect(parsed.default_value).to eq("0")
      expect(parsed.stereotypes).to eq(["PK"])
    end
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaSearchIndex do
  it "has sensible defaults" do
    index = described_class.new

    expect(index.version).to eq("1.0.0")
    expect(index.ref).to eq("id")
    expect(index.pipeline).to include("stemmer", "stopWordFilter")
  end

  it "round-trips through JSON" do
    entry = Lutaml::UmlRepository::StaticSite::Models::SpaSearchEntry.new(
      id: "test_1", type: "class", entity_type: "Class",
      entity_id: "cls_1", name: "TestClass",
      qualified_name: "Pkg::TestClass", package: "Pkg",
      content: "test class", boost: 1.5
    )

    index = described_class.new(
      fields: [{ name: "name", boost: 10 }],
      document_store: [entry],
    )

    parsed = described_class.from_json(index.to_json)
    expect(parsed.version).to eq("1.0.0")
    expect(parsed.document_store.size).to eq(1)
    expect(parsed.document_store.first.name).to eq("TestClass")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaDocument do
  it "has sensible defaults for all maps" do
    doc = described_class.new(
      metadata: Lutaml::UmlRepository::StaticSite::Models::SpaMetadata.new(
        generated: "2025-01-01", generator: "Test", version: "1.0",
        statistics: Lutaml::UmlRepository::StaticSite::Models::SpaStatistics.new
      ),
      package_tree: Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode.new(
        id: "root", name: "Root", path: "",
      ),
    )

    expect(doc.packages).to eq({})
    expect(doc.classes).to eq({})
    expect(doc.attributes).to eq({})
    expect(doc.associations).to eq({})
    expect(doc.operations).to eq({})
    expect(doc.diagrams).to eq({})
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaPackage do
  it "round-trips through JSON" do
    pkg = described_class.new(
      id: "pkg_1", xmi_id: "EAPK_1", name: "Core",
      path: "Core", definition: "Core package",
      classes: ["cls_1"], sub_packages: ["pkg_2"], diagrams: []
    )

    parsed = described_class.from_json(pkg.to_json)
    expect(parsed.name).to eq("Core")
    expect(parsed.classes).to eq(["cls_1"])
    expect(parsed.sub_packages).to eq(["pkg_2"])
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaClass do
  it "round-trips through JSON" do
    klass = described_class.new(
      id: "cls_1", xmi_id: "EAID_1", name: "Widget",
      qualified_name: "Core::Widget", type: "Class",
      package: "pkg_1", is_abstract: false,
      attributes: ["attr_1"], operations: [], associations: [],
      generalizations: [], specializations: []
    )

    parsed = described_class.from_json(klass.to_json)
    expect(parsed.name).to eq("Widget")
    expect(parsed.qualified_name).to eq("Core::Widget")
    expect(parsed.is_abstract).to be false
    expect(parsed.attributes).to eq(["attr_1"])
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaAssociation do
  it "round-trips through JSON with source and target" do
    card = Lutaml::UmlRepository::StaticSite::Models::SpaCardinality.new(
      min: "1", max: "*",
    )
    source = Lutaml::UmlRepository::StaticSite::Models::SpaAssociationEnd.new(
      klass: "EAID_A", class_name: "ClassA", role: "a_role",
      cardinality: card, aggregation: "composite"
    )
    target = Lutaml::UmlRepository::StaticSite::Models::SpaAssociationEnd.new(
      klass: "EAID_B", class_name: "ClassB", role: "b_role",
      cardinality: nil, aggregation: nil
    )

    assoc = described_class.new(
      id: "assoc_1", xmi_id: "EAID_ASSOC1", name: "link",
      type: "Association", definition: "test link",
      source: source, target: target
    )

    parsed = described_class.from_json(assoc.to_json)
    expect(parsed.name).to eq("link")
    expect(parsed.source.class_name).to eq("ClassA")
    expect(parsed.source.cardinality.min).to eq("1")
    expect(parsed.target.class_name).to eq("ClassB")
    expect(parsed.target.cardinality).to be_nil
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaOperation do
  it "round-trips through JSON with parameters" do
    param = Lutaml::UmlRepository::StaticSite::Models::SpaParameter.new(
      name: "arg1", type: "String", direction: "in",
    )

    op = described_class.new(
      id: "op_1", name: "doStuff", visibility: "public",
      return_type: "void", owner: "cls_1", owner_name: "Widget",
      parameters: [param], is_static: false, is_abstract: false
    )

    parsed = described_class.from_json(op.to_json)
    expect(parsed.name).to eq("doStuff")
    expect(parsed.parameters.size).to eq(1)
    expect(parsed.parameters.first.name).to eq("arg1")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaDiagram do
  it "round-trips through JSON" do
    diag = described_class.new(
      id: "diag_1", xmi_id: "EAID_DIAG1", name: "Overview",
      type: "Logical", package: "pkg_1",
      object_count: 5, link_count: 3, svg: nil
    )

    parsed = described_class.from_json(diag.to_json)
    expect(parsed.name).to eq("Overview")
    expect(parsed.object_count).to eq(5)
    expect(parsed.svg).to be_nil
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaPackageTreeNode do
  it "round-trips through JSON with recursive children" do
    child = described_class.new(
      id: "pkg_child", name: "Child", path: "Root::Child", class_count: 2,
    )
    root = described_class.new(
      id: "pkg_root", name: "Root", path: "Root",
      class_count: 3, children: [child]
    )

    parsed = described_class.from_json(root.to_json)
    expect(parsed.name).to eq("Root")
    expect(parsed.children.size).to eq(1)
    expect(parsed.children.first.name).to eq("Child")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaInheritedAttribute do
  it "round-trips through JSON" do
    attr = Lutaml::UmlRepository::StaticSite::Models::SpaAttribute.new(
      id: "attr_1", name: "name", type: "String",
    )
    inherited = described_class.new(
      attribute_id: "attr_1", attribute: attr,
      inherited_from: "cls_parent", inherited_from_name: "Parent",
      parent_order: 0
    )

    parsed = described_class.from_json(inherited.to_json)
    expect(parsed.attribute_id).to eq("attr_1")
    expect(parsed.inherited_from_name).to eq("Parent")
    expect(parsed.attribute.name).to eq("name")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaInheritedAssociation do
  it "round-trips through JSON" do
    inherited = described_class.new(
      association_id: "assoc_1",
      inherited_from: "cls_parent", inherited_from_name: "Parent",
      parent_order: 1, local_role: "items"
    )

    parsed = described_class.from_json(inherited.to_json)
    expect(parsed.association_id).to eq("assoc_1")
    expect(parsed.local_role).to eq("items")
    expect(parsed.parent_order).to eq(1)
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaLiteral do
  it "round-trips through JSON" do
    literal = described_class.new(name: "ACTIVE", definition: "Active state")
    parsed = described_class.from_json(literal.to_json)
    expect(parsed.name).to eq("ACTIVE")
    expect(parsed.definition).to eq("Active state")
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaStatistics do
  it "has sensible defaults" do
    stats = described_class.new
    expect(stats.packages).to eq(0)
    expect(stats.classes).to eq(0)
  end

  it "round-trips through JSON" do
    stats = described_class.new(packages: 3, classes: 10, associations: 5,
                                attributes: 20, operations: 8)
    parsed = described_class.from_json(stats.to_json)
    expect(parsed.packages).to eq(3)
    expect(parsed.classes).to eq(10)
  end
end

RSpec.describe Lutaml::UmlRepository::StaticSite::Models::SpaTreeClassRef do
  it "round-trips through JSON" do
    ref = described_class.new(id: "cls_1", name: "Widget", stereotypes: ["VO"])
    parsed = described_class.from_json(ref.to_json)
    expect(parsed.name).to eq("Widget")
    expect(parsed.stereotypes).to eq(["VO"])
  end
end
