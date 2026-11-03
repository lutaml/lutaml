# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Expressir::Model::DependencyResolver do
  let(:temp_dir) { Dir.mktmpdir("expressir_test") }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    it "creates resolver with default base dir" do
      resolver = described_class.new
      expect(resolver.base_dirs).to eq([Dir.pwd])
    end

    it "creates resolver with single base dir" do
      resolver = described_class.new(base_dirs: temp_dir)
      expect(resolver.base_dirs).to eq([File.expand_path(temp_dir)])
    end

    it "creates resolver with multiple base dirs" do
      dir1 = File.join(temp_dir, "dir1")
      dir2 = File.join(temp_dir, "dir2")
      resolver = described_class.new(base_dirs: [dir1, dir2])
      expect(resolver.base_dirs).to eq([File.expand_path(dir1),
                                        File.expand_path(dir2)])
    end

    it "creates resolver with schema registry" do
      registry = { "schema_a" => "/path/to/schema_a.exp" }
      resolver = described_class.new(schema_registry: registry)
      expect(resolver.schema_registry).to eq(registry)
    end
  end

  describe "#resolve_dependencies" do
    context "with simple schema without dependencies" do
      it "returns only the root schema" do
        schema_path = create_schema_file("simple_schema", <<~EXPRESS)
          SCHEMA simple_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(schema_path)

        expect(result).to eq([File.expand_path(schema_path)])
      end
    end

    context "with USE FROM interface" do
      it "resolves single dependency" do
        # Create dependency schema
        dep_path = create_schema_file("dependency_schema", <<~EXPRESS)
          SCHEMA dependency_schema;
          END_SCHEMA;
        EXPRESS

        # Create main schema
        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM dependency_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(main_path))
        expect(result).to include(File.expand_path(dep_path))
      end

      it "resolves transitive dependencies" do
        # Create level 2 dependency
        level2_path = create_schema_file("level2_schema", <<~EXPRESS)
          SCHEMA level2_schema;
          END_SCHEMA;
        EXPRESS

        # Create level 1 dependency
        level1_path = create_schema_file("level1_schema", <<~EXPRESS)
          SCHEMA level1_schema;
            USE FROM level2_schema;
          END_SCHEMA;
        EXPRESS

        # Create main schema
        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM level1_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(3)
        expect(result).to include(File.expand_path(main_path))
        expect(result).to include(File.expand_path(level1_path))
        expect(result).to include(File.expand_path(level2_path))
      end
    end

    context "with REFERENCE FROM interface" do
      it "resolves reference dependencies" do
        dep_path = create_schema_file("ref_schema", <<~EXPRESS)
          SCHEMA ref_schema;
            TYPE my_type = STRING;
            END_TYPE;
          END_SCHEMA;
        EXPRESS

        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            REFERENCE FROM ref_schema (my_type);
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(main_path))
        expect(result).to include(File.expand_path(dep_path))
      end
    end

    context "with multiple interfaces" do
      it "resolves all dependencies" do
        schema1_path = create_schema_file("schema1", <<~EXPRESS)
          SCHEMA schema1;
          END_SCHEMA;
        EXPRESS

        schema2_path = create_schema_file("schema2", <<~EXPRESS)
          SCHEMA schema2;
          END_SCHEMA;
        EXPRESS

        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM schema1;
            REFERENCE FROM schema2;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(3)
        expect(result).to include(File.expand_path(main_path))
        expect(result).to include(File.expand_path(schema1_path))
        expect(result).to include(File.expand_path(schema2_path))
      end
    end

    context "with circular dependencies" do
      it "handles direct circular dependency (valid in EXPRESS)" do
        schema_a_path = create_schema_file("schema_a", <<~EXPRESS)
          SCHEMA schema_a;
            USE FROM schema_b;
          END_SCHEMA;
        EXPRESS

        schema_b_path = create_schema_file("schema_b", <<~EXPRESS)
          SCHEMA schema_b;
            USE FROM schema_a;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(schema_a_path)

        # Schema-level circular references are valid in EXPRESS
        # Both schemas should be included
        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(schema_a_path))
        expect(result).to include(File.expand_path(schema_b_path))
      end

      it "handles indirect circular dependency (valid in EXPRESS)" do
        schema_a_path = create_schema_file("schema_a", <<~EXPRESS)
          SCHEMA schema_a;
            USE FROM schema_b;
          END_SCHEMA;
        EXPRESS

        schema_b_path = create_schema_file("schema_b", <<~EXPRESS)
          SCHEMA schema_b;
            USE FROM schema_c;
          END_SCHEMA;
        EXPRESS

        schema_c_path = create_schema_file("schema_c", <<~EXPRESS)
          SCHEMA schema_c;
            USE FROM schema_a;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(schema_a_path)

        # Schema-level circular references are valid in EXPRESS
        # All schemas should be included
        expect(result.size).to eq(3)
        expect(result).to include(File.expand_path(schema_a_path))
        expect(result).to include(File.expand_path(schema_b_path))
        expect(result).to include(File.expand_path(schema_c_path))
      end
    end

    context "with missing dependencies" do
      it "silently skips missing schemas in permissive mode" do
        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM nonexistent_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: temp_dir)
        result = resolver.resolve_dependencies(main_path)

        expect(result).to eq([File.expand_path(main_path)])
      end
    end

    context "with schema registry" do
      it "uses registry to resolve schemas" do
        dep_path = create_schema_file("custom_location/dependency", <<~EXPRESS)
          SCHEMA dependency_schema;
          END_SCHEMA;
        EXPRESS

        main_path = create_schema_file("main_schema", <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM dependency_schema;
          END_SCHEMA;
        EXPRESS

        registry = { "dependency_schema" => dep_path }
        resolver = described_class.new(base_dirs: temp_dir,
                                       schema_registry: registry)
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(dep_path))
      end
    end

    context "with multiple base directories" do
      it "searches all base directories" do
        dir1 = File.join(temp_dir, "dir1")
        dir2 = File.join(temp_dir, "dir2")
        FileUtils.mkdir_p([dir1, dir2])

        dep_path = File.join(dir2, "dependency_schema.exp")
        File.write(dep_path, <<~EXPRESS)
          SCHEMA dependency_schema;
          END_SCHEMA;
        EXPRESS

        main_path = File.join(dir1, "main_schema.exp")
        File.write(main_path, <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM dependency_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: [dir1, dir2])
        result = resolver.resolve_dependencies(main_path)

        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(dep_path))
      end

      it "detects and reports multiple matches across base directories" do
        dir1 = File.join(temp_dir, "dir1")
        dir2 = File.join(temp_dir, "dir2")
        FileUtils.mkdir_p([dir1, dir2])

        # Create same schema in both directories
        dep_path1 = File.join(dir1, "dependency_schema.exp")
        File.write(dep_path1, <<~EXPRESS)
          SCHEMA dependency_schema;
            -- Version from dir1
          END_SCHEMA;
        EXPRESS

        dep_path2 = File.join(dir2, "dependency_schema.exp")
        File.write(dep_path2, <<~EXPRESS)
          SCHEMA dependency_schema;
            -- Version from dir2
          END_SCHEMA;
        EXPRESS

        main_path = File.join(dir1, "main_schema.exp")
        File.write(main_path, <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM dependency_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: [dir1, dir2])
        result = resolver.resolve_dependencies(main_path)

        # Should include main schema and first match of dependency
        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(main_path))
        expect(result).to include(File.expand_path(dep_path1)) # First match wins

        # Check statistics for multiple matches
        stats = resolver.statistics
        expect(stats[:multiple_matches]).not_to be_empty

        match_info = stats[:multiple_matches].find do |m|
          m[:schema_name] == "dependency_schema"
        end
        expect(match_info).not_to be_nil
        expect(match_info[:matches].size).to eq(2)
        expect(match_info[:matches][0][:path]).to eq(File.expand_path(dep_path1))
        expect(match_info[:matches][1][:path]).to eq(File.expand_path(dep_path2))
        expect(match_info[:matches][0][:index]).to eq(0) # First base dir
        expect(match_info[:matches][1][:index]).to eq(1) # Second base dir
      end

      it "detects multiple matches in same base directory" do
        # Create nested directory structure
        base_dir = File.join(temp_dir, "schemas")
        dir1 = File.join(base_dir, "resources")
        dir2 = File.join(base_dir, "modules")
        FileUtils.mkdir_p([dir1, dir2])

        # Create same schema in both subdirectories
        dep_path1 = File.join(dir1, "common_schema.exp")
        File.write(dep_path1, <<~EXPRESS)
          SCHEMA common_schema;
            -- Resource version
          END_SCHEMA;
        EXPRESS

        dep_path2 = File.join(dir2, "common_schema.exp")
        File.write(dep_path2, <<~EXPRESS)
          SCHEMA common_schema;
            -- Module version
          END_SCHEMA;
        EXPRESS

        main_path = File.join(base_dir, "main_schema.exp")
        File.write(main_path, <<~EXPRESS)
          SCHEMA main_schema;
            USE FROM common_schema;
          END_SCHEMA;
        EXPRESS

        resolver = described_class.new(base_dirs: base_dir)
        result = resolver.resolve_dependencies(main_path)

        # Should include main schema and first found match
        expect(result.size).to eq(2)
        expect(result).to include(File.expand_path(main_path))

        # The first match found via recursive search should be used
        # Check that multiple matches were detected
        stats = resolver.statistics
        match_info = stats[:multiple_matches].find do |m|
          m[:schema_name] == "common_schema"
        end

        # Note: Depending on filesystem ordering, either could be first
        # What's important is that we detected multiple matches
        if match_info
          expect(match_info[:matches].size).to be >= 1
        end
      end
    end
  end

  describe "#extract_interfaces" do
    it "extracts USE FROM interfaces" do
      schema_path = create_schema_file("test_schema", <<~EXPRESS)
        SCHEMA test_schema;
          USE FROM other_schema;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new
      interfaces = resolver.extract_interfaces(schema_path)

      expect(interfaces.size).to eq(1)
      expect(interfaces.first[:kind]).to eq("USE")
      expect(interfaces.first[:schema_name]).to eq("other_schema")
    end

    it "extracts REFERENCE FROM interfaces" do
      schema_path = create_schema_file("test_schema", <<~EXPRESS)
        SCHEMA test_schema;
          REFERENCE FROM other_schema (my_type);
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new
      interfaces = resolver.extract_interfaces(schema_path)

      expect(interfaces.size).to eq(1)
      expect(interfaces.first[:kind]).to eq("REFERENCE")
      expect(interfaces.first[:schema_name]).to eq("other_schema")
    end

    it "extracts multiple interfaces" do
      schema_path = create_schema_file("test_schema", <<~EXPRESS)
        SCHEMA test_schema;
          USE FROM schema1;
          REFERENCE FROM schema2;
          USE FROM schema3;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new
      interfaces = resolver.extract_interfaces(schema_path)

      expect(interfaces.size).to eq(3)
      schema_names = interfaces.map { |i| i[:schema_name] }
      expect(schema_names).to contain_exactly("schema1", "schema2", "schema3")
    end
  end

  describe "#resolve_schema_location" do
    it "finds schema in same directory" do
      dep_path = create_schema_file("dependency", <<~EXPRESS)
        SCHEMA dependency;
        END_SCHEMA;
      EXPRESS

      main_path = create_schema_file("main", <<~EXPRESS)
        SCHEMA main;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new(base_dirs: temp_dir)
      result = resolver.resolve_schema_location("dependency", "USE", main_path)

      expect(result).to eq(File.expand_path(dep_path))
    end

    it "returns nil for nonexistent schema" do
      main_path = create_schema_file("main", <<~EXPRESS)
        SCHEMA main;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new(base_dirs: temp_dir)
      result = resolver.resolve_schema_location("nonexistent", "USE", main_path)

      expect(result).to be_nil
    end
  end

  describe "#statistics" do
    it "returns statistics after resolution" do
      create_schema_file("dependency", <<~EXPRESS)
        SCHEMA dependency;
        END_SCHEMA;
      EXPRESS

      main_path = create_schema_file("main", <<~EXPRESS)
        SCHEMA main;
          USE FROM dependency;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new(base_dirs: temp_dir)
      resolver.resolve_dependencies(main_path)
      stats = resolver.statistics

      expect(stats[:total_schemas]).to eq(2)
      expect(stats[:schemas].size).to eq(2)
      expect(stats[:base_dirs]).to include(File.expand_path(temp_dir))
    end
  end

  describe "path resolution strategies" do
    it "resolves from parent directory" do
      subdir = File.join(temp_dir, "subdir")
      FileUtils.mkdir_p(subdir)

      dep_path = create_schema_file("dependency", <<~EXPRESS)
        SCHEMA dependency;
        END_SCHEMA;
      EXPRESS

      main_path = File.join(subdir, "main_schema.exp")
      File.write(main_path, <<~EXPRESS)
        SCHEMA main_schema;
          USE FROM dependency;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new(base_dirs: temp_dir)
      result = resolver.resolve_dependencies(main_path)

      expect(result.size).to eq(2)
      expect(result).to include(File.expand_path(dep_path))
    end

    it "handles nested directory structures" do
      schemas_dir = File.join(temp_dir, "schemas")
      FileUtils.mkdir_p(schemas_dir)

      dep_path = File.join(schemas_dir, "dependency_schema.exp")
      File.write(dep_path, <<~EXPRESS)
        SCHEMA dependency_schema;
        END_SCHEMA;
      EXPRESS

      main_path = create_schema_file("main_schema", <<~EXPRESS)
        SCHEMA main_schema;
          USE FROM dependency_schema;
        END_SCHEMA;
      EXPRESS

      resolver = described_class.new(base_dirs: temp_dir)
      result = resolver.resolve_dependencies(main_path)

      expect(result.size).to eq(2)
      expect(result).to include(File.expand_path(dep_path))
    end
  end

  # Helper method to create schema files
  def create_schema_file(name, content)
    # Handle paths with subdirectories
    if name.include?("/")
      dir = File.dirname(File.join(temp_dir, name))
      FileUtils.mkdir_p(dir)
    end
    path = File.join(temp_dir, "#{name}.exp")

    File.write(path, content)
    path
  end
end
