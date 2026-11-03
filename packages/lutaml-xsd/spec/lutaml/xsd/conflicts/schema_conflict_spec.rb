# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lutaml::Xsd::Conflicts::SchemaConflict do
  describe Lutaml::Xsd::Conflicts::SchemaFileSource do
    let(:package_path) { "package1.lxr" }
    let(:schema_file) { "schemas/person.xsd" }
    let(:priority) { 5 }

    describe "initialization" do
      it "creates file source with all attributes" do
        source = described_class.new(
          package_path: package_path,
          schema_file: schema_file,
          priority: priority,
        )

        expect(source.package_path).to eq(package_path)
        expect(source.schema_file).to eq(schema_file)
        expect(source.priority).to eq(priority)
      end
    end

    describe "serialization" do
      let(:source) do
        described_class.new(
          package_path: package_path,
          schema_file: schema_file,
          priority: priority,
        )
      end

      describe "#to_hash" do
        it "converts to hash" do
          hash = source.to_hash

          expect(hash["package_path"]).to eq(package_path)
          expect(hash["schema_file"]).to eq(schema_file)
          expect(hash["priority"]).to eq(priority)
        end
      end

      describe "#to_yaml" do
        it "serializes to YAML" do
          yaml = source.to_yaml

          expect(yaml).to include("package_path: package1.lxr")
          expect(yaml).to include("schema_file: schemas/person.xsd")
          expect(yaml).to include("priority: 5")
        end

        it "round-trips through YAML" do
          yaml = source.to_yaml
          restored = described_class.from_yaml(yaml)

          expect(restored.package_path).to eq(package_path)
          expect(restored.schema_file).to eq(schema_file)
          expect(restored.priority).to eq(priority)
        end
      end

      describe "#to_json" do
        it "serializes to JSON" do
          json = source.to_json

          expect(json).to include('"package_path":"package1.lxr"')
          expect(json).to include('"schema_file":"schemas/person.xsd"')
          expect(json).to include('"priority":5')
        end

        it "round-trips through JSON" do
          json = source.to_json
          restored = described_class.from_json(json)

          expect(restored.package_path).to eq(package_path)
          expect(restored.schema_file).to eq(schema_file)
          expect(restored.priority).to eq(priority)
        end
      end
    end
  end

  describe Lutaml::Xsd::Conflicts::SchemaConflict do
    let(:schema_basename) { "person.xsd" }
    let(:source_files) do
      [
        Lutaml::Xsd::Conflicts::SchemaFileSource.new(
          package_path: "package1.lxr",
          schema_file: "schemas/person.xsd",
          priority: 0,
        ),
        Lutaml::Xsd::Conflicts::SchemaFileSource.new(
          package_path: "package2.lxr",
          schema_file: "xsd/person.xsd",
          priority: 10,
        ),
      ]
    end

    describe "initialization" do
      it "creates conflict with basename and sources" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        expect(conflict.schema_basename).to eq(schema_basename)
        expect(conflict.source_files).to eq(source_files)
      end
    end

    describe "#conflict_count" do
      it "returns number of source files" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        expect(conflict.conflict_count).to eq(2)
      end

      it "handles single source" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: [source_files[0]],
        )

        expect(conflict.conflict_count).to eq(1)
      end
    end

    describe "#package_paths" do
      it "extracts package paths from source files" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        expect(conflict.package_paths).to eq(["package1.lxr", "package2.lxr"])
      end
    end

    describe "#file_paths" do
      it "extracts file paths from source files" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        expect(conflict.file_paths).to eq(["schemas/person.xsd",
                                           "xsd/person.xsd"])
      end
    end

    describe "#highest_priority_source" do
      it "returns source with lowest priority number" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        highest = conflict.highest_priority_source
        expect(highest.package_path).to eq("package1.lxr")
        expect(highest.priority).to eq(0)
      end

      it "handles reversed priorities" do
        reversed_sources = [
          Lutaml::Xsd::Conflicts::SchemaFileSource.new(
            package_path: "package1.lxr",
            schema_file: "schemas/person.xsd",
            priority: 10,
          ),
          Lutaml::Xsd::Conflicts::SchemaFileSource.new(
            package_path: "package2.lxr",
            schema_file: "xsd/person.xsd",
            priority: 0,
          ),
        ]

        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: reversed_sources,
        )

        highest = conflict.highest_priority_source
        expect(highest.package_path).to eq("package2.lxr")
        expect(highest.priority).to eq(0)
      end
    end

    describe "#to_s" do
      it "returns human-readable summary" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        expect(conflict.to_s).to eq("Schema 'person.xsd' found in 2 packages")
      end
    end

    describe "#detailed_description" do
      it "returns detailed conflict information" do
        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )

        description = conflict.detailed_description
        expect(description).to include("Schema File Conflict:")
        expect(description).to include("Schema: person.xsd")
        expect(description).to include("Found in packages:")
        expect(description).to include("- package1.lxr (priority: 0)")
        expect(description).to include("File: schemas/person.xsd")
        expect(description).to include("- package2.lxr (priority: 10)")
        expect(description).to include("File: xsd/person.xsd")
      end

      it "formats multiple sources properly" do
        multiple_sources = [
          Lutaml::Xsd::Conflicts::SchemaFileSource.new(
            package_path: "pkg1.lxr",
            schema_file: "a/person.xsd",
            priority: 0,
          ),
          Lutaml::Xsd::Conflicts::SchemaFileSource.new(
            package_path: "pkg2.lxr",
            schema_file: "b/person.xsd",
            priority: 5,
          ),
          Lutaml::Xsd::Conflicts::SchemaFileSource.new(
            package_path: "pkg3.lxr",
            schema_file: "c/person.xsd",
            priority: 10,
          ),
        ]

        conflict = described_class.new(
          schema_basename: schema_basename,
          source_files: multiple_sources,
        )

        description = conflict.detailed_description
        expect(description).to include("- pkg1.lxr (priority: 0)")
        expect(description).to include("File: a/person.xsd")
        expect(description).to include("- pkg2.lxr (priority: 5)")
        expect(description).to include("File: b/person.xsd")
        expect(description).to include("- pkg3.lxr (priority: 10)")
        expect(description).to include("File: c/person.xsd")
      end
    end

    describe "serialization" do
      let(:conflict) do
        described_class.new(
          schema_basename: schema_basename,
          source_files: source_files,
        )
      end

      describe "#to_hash" do
        it "converts to hash with nested source files" do
          hash = conflict.to_hash

          expect(hash["schema_basename"]).to eq(schema_basename)
          expect(hash["source_files"]).to be_an(Array)
          expect(hash["source_files"].size).to eq(2)

          first_source = hash["source_files"][0]
          expect(first_source["package_path"]).to eq("package1.lxr")
          expect(first_source["schema_file"]).to eq("schemas/person.xsd")
          expect(first_source["priority"]).to eq(0)
        end
      end

      describe "#to_yaml" do
        it "serializes to YAML with nested sources" do
          yaml = conflict.to_yaml

          expect(yaml).to include("schema_basename: person.xsd")
          expect(yaml).to include("source_files:")
          expect(yaml).to include("package_path: package1.lxr")
          expect(yaml).to include("schema_file: schemas/person.xsd")
          expect(yaml).to include("priority: 0")
          expect(yaml).to include("package_path: package2.lxr")
          expect(yaml).to include("schema_file: xsd/person.xsd")
          expect(yaml).to include("priority: 10")
        end

        it "round-trips through YAML" do
          yaml = conflict.to_yaml
          restored = described_class.from_yaml(yaml)

          expect(restored.schema_basename).to eq(schema_basename)
          expect(restored.source_files.size).to eq(2)
          expect(restored.source_files[0].package_path).to eq("package1.lxr")
          expect(restored.source_files[1].package_path).to eq("package2.lxr")
        end
      end

      describe "#to_json" do
        it "serializes to JSON with nested sources" do
          json = conflict.to_json

          expect(json).to include('"schema_basename":"person.xsd"')
          expect(json).to include('"source_files":[')
          expect(json).to include('"package_path":"package1.lxr"')
          expect(json).to include('"schema_file":"schemas/person.xsd"')
          expect(json).to include('"priority":0')
        end

        it "round-trips through JSON" do
          json = conflict.to_json
          restored = described_class.from_json(json)

          expect(restored.schema_basename).to eq(schema_basename)
          expect(restored.source_files.size).to eq(2)
          expect(restored.source_files[0].package_path).to eq("package1.lxr")
          expect(restored.source_files[1].package_path).to eq("package2.lxr")
        end
      end
    end
  end
end
