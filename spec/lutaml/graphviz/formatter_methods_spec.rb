# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Formatter::Graphviz do
  let(:formatter) { described_class.new }

  describe "#format_attribute" do
    it "renders public attribute with type" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "count", visibility: "public", type: "Integer"
      )
      expect(formatter.format_attribute(attr)).to eq("+count : Integer")
    end

    it "renders private attribute" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "secret", visibility: "private"
      )
      expect(formatter.format_attribute(attr)).to eq("-secret")
    end

    it "renders protected attribute" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "internal", visibility: "protected"
      )
      expect(formatter.format_attribute(attr)).to eq("#internal")
    end

    it "renders attribute with stereotype" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "id", visibility: "public", type: "String", stereotype: ["PK"]
      )
      expect(formatter.format_attribute(attr)).to eq("+id : «PK»String")
    end

    it "renders attribute with cardinality" do
      card = Lutaml::Lml::Cardinality.new(min: "0", max: "*")
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "items", visibility: "public", type: "String",
        cardinality: card
      )
      result = formatter.format_attribute(attr)
      expect(result).to include("&#91;0..*&#93;")
    end

    it "renders static attribute with underline" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "instance", visibility: "public", static: "true"
      )
      expect(formatter.format_attribute(attr)).to eq("<U>+instance</U>")
    end

    it "escapes HTML characters in name" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "data<Field>", visibility: "public"
      )
      result = formatter.format_attribute(attr)
      expect(result).to eq("+data&#60;Field&#62;")
    end

    it "defaults cardinality nil bounds to *" do
      card = Lutaml::Lml::Cardinality.new(min: "0")
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "items", visibility: "public", cardinality: card
      )
      result = formatter.format_attribute(attr)
      expect(result).to include("&#91;0..*&#93;")
    end

    it "defaults cardinality nil min to *" do
      card = Lutaml::Lml::Cardinality.new(max: "1")
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "items", visibility: "public", cardinality: card
      )
      result = formatter.format_attribute(attr)
      expect(result).to include("&#91;*..1&#93;")
    end
  end

  describe "#format_operation" do
    it "renders operation with visibility and parameters" do
      param = Lutaml::Lml::OperationParameter.new(name: "id", type: "Integer")
      op = Lutaml::Lml::Operation.new(
        name: "find", visibility: "public", owned_parameter: [param]
      )
      result = formatter.format_operation(op)
      expect(result).to eq("+ find(id : Integer)")
    end

    it "renders operation with return type" do
      op = Lutaml::Lml::Operation.new(
        name: "count", visibility: "public", return_type: "Integer"
      )
      result = formatter.format_operation(op)
      expect(result).to eq("+ count() : Integer")
    end

    it "renders static operation with underline" do
      op = Lutaml::Lml::Operation.new(
        name: "create", visibility: "public", is_static: true
      )
      result = formatter.format_operation(op)
      expect(result).to eq("<U>+ create()</U>")
    end

    it "renders abstract operation with italic" do
      op = Lutaml::Lml::Operation.new(
        name: "execute", visibility: "public", is_abstract: true
      )
      result = formatter.format_operation(op)
      expect(result).to eq("<I>+ execute()</I>")
    end

    it "renders operation with no parameters" do
      op = Lutaml::Lml::Operation.new(name: "run", visibility: "private")
      result = formatter.format_operation(op)
      expect(result).to eq("- run()")
    end

    it "escapes HTML characters in name and return type" do
      op = Lutaml::Lml::Operation.new(
        name: "process<Item>", visibility: "public", return_type: "List<T>"
      )
      result = formatter.format_operation(op)
      expect(result).to include("&#60;Item&#62;")
      expect(result).to include("List&#60;T&#62;")
    end

    it "escapes ampersand in name" do
      op = Lutaml::Lml::Operation.new(
        name: "find&replace", visibility: "public"
      )
      result = formatter.format_operation(op)
      expect(result).to include("find&amp;replace")
    end
  end

  describe "#format_label" do
    it "formats label with cardinality" do
      card = Lutaml::Lml::Cardinality.new(min: "1", max: "*")
      result = formatter.format_label("items", card)
      expect(result).to eq("+items 1..*")
    end

    it "returns name only when cardinality is nil" do
      result = formatter.format_label("name", nil)
      expect(result).to eq("+name")
    end
  end

  describe "#escape_html_chars" do
    it "escapes angle brackets and square brackets" do
      result = formatter.escape_html_chars("<class>[0]")
      expect(result).to eq("&#60;class&#62;&#91;0&#93;")
    end

    it "escapes ampersand before other characters" do
      result = formatter.escape_html_chars("foo&bar<z>")
      expect(result).to eq("foo&amp;bar&#60;z&#62;")
    end
  end

  describe "#format_class" do
    it "renders class with stereotype" do
      klass = Lutaml::Lml::UmlClass.new(name: "Service", stereotype: ["interface"])
      result = formatter.format_class(klass, nil)
      expect(result).to include("«interface»")
      expect(result).to include("<B>Service</B>")
    end

    it "renders class with attributes" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "id", visibility: "public", type: "String"
      )
      klass = Lutaml::Lml::UmlClass.new(name: "Entity", attributes: [attr])
      result = formatter.format_class(klass, nil)
      expect(result).to include("+id : String")
    end

    it "renders empty table when hide_members is true" do
      attr = Lutaml::Lml::TopElementAttribute.new(name: "hidden", visibility: "public")
      klass = Lutaml::Lml::UmlClass.new(name: "Hidden", attributes: [attr])
      result = formatter.format_class(klass, true)
      expect(result).not_to include("hidden")
    end

    it "escapes HTML characters in class name" do
      klass = Lutaml::Lml::UmlClass.new(name: "My<Class>")
      result = formatter.format_class(klass, nil)
      expect(result).to include("&#60;Class&#62;")
    end

    it "escapes HTML characters in stereotype" do
      klass = Lutaml::Lml::UmlClass.new(name: "Service", stereotype: ["interface>"])
      result = formatter.format_class(klass, nil)
      expect(result).to include("&#62;")
    end

    it "renders name table rows with proper newlines" do
      klass = Lutaml::Lml::UmlClass.new(name: "Svc", stereotype: ["intf"])
      result = formatter.format_class(klass, nil)
      rows = result.scan('<TR><TD ALIGN="CENTER">')
      expect(rows.length).to be >= 2
      expect(result).not_to include("\\n")
    end

    it "works without hide_members argument via dispatch" do
      klass = Lutaml::Lml::UmlClass.new(name: "Test")
      result = formatter.format_class(klass)
      expect(result).to include("<B>Test</B>")
    end
  end

  describe "#format_class for enums" do
    it "renders enum literals in italic" do
      attr = Lutaml::Lml::TopElementAttribute.new(name: "draft")
      enum = Lutaml::Lml::Enum.new(name: "Status", attributes: [attr])
      result = formatter.format_class(enum, nil)
      expect(result).to include("<I>draft</I>")
    end

    it "renders enum attribute with cardinality as regular attribute" do
      card = Lutaml::Lml::Cardinality.new(min: "1", max: "*")
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "items", visibility: "private", cardinality: card
      )
      enum = Lutaml::Lml::Enum.new(name: "Container", attributes: [attr])
      result = formatter.format_class(enum, nil)
      expect(result).to include("-items")
      expect(result).not_to include("<I>items</I>")
    end

    it "renders enum attribute with type as regular attribute" do
      attr = Lutaml::Lml::TopElementAttribute.new(
        name: "code", visibility: "public", type: "String"
      )
      enum = Lutaml::Lml::Enum.new(name: "Codes", attributes: [attr])
      result = formatter.format_class(enum, nil)
      expect(result).to include("+code : String")
      expect(result).not_to include("<I>code</I>")
    end

    it "renders enumeration stereotype for enums" do
      enum = Lutaml::Lml::Enum.new(name: "Color")
      result = formatter.format_class(enum, nil)
      expect(result).to include("«enumeration»")
    end
  end

  describe "#indent_lines" do
    it "indents each line with two spaces" do
      result = formatter.indent_lines("line1\nline2")
      expect(result).to eq("  line1\n  line2")
    end
  end

  describe "#format_relationship" do
    it "renders composition edge" do
      assoc = Lutaml::Lml::Association.new(
        owner_end: "Order", member_end: "LineItem",
        owner_end_type: "composition", member_end_type: "direct"
      )
      result = formatter.format_relationship(assoc)
      expect(result).to include("Order -> LineItem")
      expect(result).to include('arrowtail="diamond"')
    end

    it "renders dashed style for dependency" do
      assoc = Lutaml::Lml::Association.new(
        owner_end: "Client", member_end: "Service",
        member_end_type: "dependency"
      )
      result = formatter.format_relationship(assoc)
      expect(result).to include('style="dashed"')
    end

    it "renders edge with action verb label" do
      action = Lutaml::Lml::Action.new(verb: "uses")
      assoc = Lutaml::Lml::Association.new(
        owner_end: "A", member_end: "B",
        action: action
      )
      result = formatter.format_relationship(assoc)
      expect(result).to include('label="uses"')
    end

    it "renders endpoint labels" do
      card = Lutaml::Lml::Cardinality.new(min: "1", max: "*")
      assoc = Lutaml::Lml::Association.new(
        owner_end: "Order", member_end: "Item",
        owner_end_attribute_name: "items",
        owner_end_cardinality: card,
        member_end_type: "direct"
      )
      result = formatter.format_relationship(assoc)
      expect(result).to include("headlabel=")
      expect(result).to include("+items")
    end

    it "renders bidirectional edge when both end types present" do
      assoc = Lutaml::Lml::Association.new(
        owner_end: "Parent", member_end: "Child",
        owner_end_type: "composition", member_end_type: "direct"
      )
      result = formatter.format_relationship(assoc)
      expect(result).to include('dir="both"')
    end
  end

  describe "#extract_fidelity_options" do
    it "returns nil pair when no fidelity" do
      doc = Lutaml::Lml::Document.new
      expect(formatter.extract_fidelity_options(doc)).to eq([nil, nil])
    end
  end
end
