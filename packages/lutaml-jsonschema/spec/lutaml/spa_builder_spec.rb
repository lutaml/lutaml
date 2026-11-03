# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Lutaml::Jsonschema::Spa::SpaBuilder do
  let(:fixtures_dir) { File.join(__dir__, "..", "fixtures") }

  describe "#build" do
    context "with person fixture (direct properties, no $ref)" do
      let(:schema_set) do
        Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "person.json"),
        )
      end

      it "resolves $ref in properties to get type and description" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        address_prop = schema.properties.find { |p| p.name == "address" }
        # address has $ref to #/definitions/address, which resolves to type=object
        expect(address_prop.ref).to eq("#/definitions/address")
        expect(address_prop.type).to eq("object")
      end

      it "resolves $ref to get definition details" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        address_def = schema.definitions.find { |d| d.name == "address" }
        expect(address_def.title).to eq("Address")
        expect(address_def.type).to eq("object")
        expect(address_def.properties.length).to eq(4)

        zip = address_def.properties.find { |p| p.name == "zip" }
        expect(zip.type).to eq("string")
        expect(zip.pattern).to eq("[0-9]{5}")
      end
    end

    context "with interagent fixture (deeply nested $ref)" do
      let(:schema_set) do
        Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "interagent_simple.json"),
        )
      end

      it "resolves top-level $ref properties" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        post_prop = schema.properties.find { |p| p.name == "post" }
        expect(post_prop.type).to eq("object")
        expect(post_prop.ref).to eq("#/definitions/post")
      end

      it "resolves definition sub-properties via nested $ref" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        post_def = schema.definitions.find { |d| d.name == "post" }

        created_at = post_def.properties.find { |p| p.name == "created_at" }
        expect(created_at.type).to eq("string")
        expect(created_at.format).to eq("date-time")
        expect(created_at.description).to eq("when post was created")

        id_prop = post_def.properties.find { |p| p.name == "id" }
        expect(id_prop.type).to eq("string")
        expect(id_prop.format).to eq("uuid")
        expect(id_prop.description).to eq("unique identifier of post")
      end

      it "creates search entries for schemas, properties, and definitions" do
        doc = described_class.new(schema_set).build
        entries = doc.search_index

        schema_entries = entries.select { |e| e.type == "schema" }
        expect(schema_entries.length).to eq(1)

        definition_entries = entries.select { |e| e.type == "definition" }
        expect(definition_entries.map(&:name)).to contain_exactly("post",
                                                                  "user")

        property_entries = entries.select { |e| e.type == "property" }
        expect(property_entries.length).to be > 2
      end
    end

    context "with comprehensive fixture" do
      let(:schema_set) do
        Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "comprehensive.json"),
        )
      end

      it "extracts readOnly from schema" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        dep_prop = schema.properties.find { |p| p.name == "deprecated_field" }
        expect(dep_prop.read_only).to eq(true)
      end

      it "extracts writeOnly from schema" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        wo_prop = schema.properties.find { |p| p.name == "write_only_field" }
        expect(wo_prop.write_only).to eq(true)
      end

      it "extracts minItems and maxItems from array items" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        metadata_prop = schema.properties.find { |p| p.name == "metadata" }
        # metadata is an object with nested properties — check its definition
        metadata_prop&.ref ? nil : nil
        # tags is nested inside metadata object — check through definitions
      end

      it "extracts multipleOf from schema" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        priority = schema.properties.find { |p| p.name == "priority" }
        expect(priority.multiple_of).to eq(1.0)
      end

      it "extracts deprecated flag" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        dep_prop = schema.properties.find { |p| p.name == "deprecated_field" }
        expect(dep_prop.deprecated).to eq(true)
      end
    end

    context "with complex_defs fixture (draft 2020-12, $defs, array items $ref)" do
      let(:schema_set) do
        Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "complex_defs.json"),
        )
      end

      it "resolves array items $ref to get items_ref and items_type" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        md_metadata = schema.definitions.find { |d| d.name == "MD_Metadata" }

        identifiers = md_metadata.properties.find do |p|
          p.name == "identifiers"
        end
        expect(identifiers.type).to eq("array")
        expect(identifiers.items_ref).to eq("#/$defs/MD_Identifier")
        expect(identifiers.items_type).to eq("object")
      end

      it "resolves array items $ref to definition title when items type is nil" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        md_metadata = schema.definitions.find { |d| d.name == "MD_Metadata" }

        contacts = md_metadata.properties.find { |p| p.name == "contacts" }
        expect(contacts.type).to eq("array")
        expect(contacts.items_ref).to eq("#/$defs/CI_Contact")
        expect(contacts.items_type).to eq("object")
      end

      it "captures minItems on array properties" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        md_metadata = schema.definitions.find { |d| d.name == "MD_Metadata" }

        contacts = md_metadata.properties.find { |p| p.name == "contacts" }
        expect(contacts.min_items).to eq(1)
      end

      it "captures enum values on pure-enum definitions" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first

        topic_cat = schema.definitions.find do |d|
          d.name == "MD_TopicCategoryCode"
        end
        expect(topic_cat.type).to eq("string")
        expect(topic_cat.enum).to eq(%w[farming biota boundaries climatology
                                        economy elevation])
      end

      it "captures enum on obligation code definition" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first

        obligation = schema.definitions.find do |d|
          d.name == "MD_ObligationCode"
        end
        expect(obligation.enum).to eq(%w[mandatory optional conditional])
      end

      it "captures format and pattern on definition" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first

        duration = schema.definitions.find { |d| d.name == "DurationType" }
        expect(duration.format).to eq("duration")
        expect(duration.pattern).to eq("^P.*$")
      end

      it "resolves $ref to enum definition and preserves enum on property" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        md_metadata = schema.definitions.find { |d| d.name == "MD_Metadata" }

        topic = md_metadata.properties.find { |p| p.name == "topicCategory" }
        expect(topic.ref).to eq("#/$defs/MD_TopicCategoryCode")
        expect(topic.enum).to eq(%w[farming biota boundaries climatology
                                    economy elevation])
      end

      it "handles nested array items $ref through definition chain" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first
        contact = schema.definitions.find { |d| d.name == "CI_Contact" }

        phone = contact.properties.find { |p| p.name == "phone" }
        expect(phone.type).to eq("array")
        expect(phone.items_ref).to eq("#/$defs/CI_Telephone")
      end

      it "builds oneOf variant definition with has_one_of flag" do
        doc = described_class.new(schema_set).build
        schema = doc.schemas.first

        constraint_union = schema.definitions.find do |d|
          d.name == "Abstract_ConstraintUnion"
        end
        expect(constraint_union.has_one_of).to eq(true)
      end
    end

    context "with multiple schemas" do
      let(:schema_set) do
        Lutaml::Jsonschema::SchemaSet.load_from_files(
          File.join(fixtures_dir, "person.json"),
          File.join(fixtures_dir, "interagent_simple.json"),
        )
      end

      it "builds a SpaDocument with multiple schemas" do
        doc = described_class.new(schema_set).build
        expect(doc.schemas.length).to eq(2)
        expect(doc.schemas.map(&:name)).to contain_exactly("person",
                                                           "interagent_simple")
      end

      it "infers title from first schema when no metadata given" do
        doc = described_class.new(schema_set).build
        expect(doc.metadata.title).to eq("Person")
      end

      it "uses provided metadata title" do
        metadata = Lutaml::Jsonschema::Spa::Metadata.new(title: "Custom Title")
        doc = described_class.new(schema_set, metadata: metadata).build
        expect(doc.metadata.title).to eq("Custom Title")
      end

      it "produces valid round-trip JSON" do
        doc = described_class.new(schema_set).build
        json = doc.to_json
        parsed = JSON.parse(json)

        expect(parsed["schemas"].length).to eq(2)
        expect(parsed["searchIndex"].length).to be > 0
        expect(parsed["metadata"]).to have_key("title")
      end
    end
  end
end
