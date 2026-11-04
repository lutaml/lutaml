# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Expressir::Commands::ParityInputs do
  def write(dir, name, body)
    File.write(File.join(dir, name), body)
    File.join(dir, name)
  end

  def arm_body
    <<~EXP
      SCHEMA m_arm;
      ENTITY thing; a : STRING; END_ENTITY;
      END_SCHEMA;
    EXP
  end

  def mim_body
    <<~EXP
      SCHEMA m_mim;
      USE FROM m_arm (thing);
      ENTITY thing; a : STRING; END_ENTITY;
      END_SCHEMA;
    EXP
  end

  describe ".closure_paths" do
    it "resolves through an ELF schema manifest first" do
      Dir.mktmpdir("resolver") do |dir|
        arm = write(dir, "arm_anywhere.exp", arm_body)
        mim = write(dir, "mim_anywhere.exp", mim_body)
        manifest = File.join(dir, "manifest.yaml")
        File.write(manifest, <<~YAML)
          ---
          schemas:
            m_arm:
              path: #{arm}
            m_mim:
              path: #{mim}
        YAML
        root = write(dir, "mim.exp", mim_body)

        paths = described_class.closure_paths(root, manifest: manifest)
        expect(paths).to include(arm)
      end
    end

    it "resolves through a STEPmod root as the fallback" do
      Dir.mktmpdir("resolver") do |dir|
        schemas = File.join(dir, "schemas")
        FileUtils.mkdir_p(schemas)
        arm = write(schemas, "m_arm.exp", arm_body)
        _ = write(schemas, "m_mim.exp", mim_body)
        root = write(schemas, "mim.exp", mim_body)

        paths = described_class.closure_paths(root, stepmod: dir)
        # m_arm.exp / m_mim.exp live under schemas/ with names that only
        # the stepmod directory convention can resolve
        expect(paths).to include(arm)
      end
    end

    it "strips remarks before scanning interface names" do
      Dir.mktmpdir("resolver") do |dir|
        root = write(dir, "plain.exp", <<~EXP)
          SCHEMA plain;
          -- use from the main schema
          ENTITY e; x : STRING; END_ENTITY;
          END_SCHEMA;
        EXP

        paths = described_class.closure_paths(root)
        expect(paths).to eq([root])
      end
    end

    it "raises with a resolver hint when a dependency is missing (#449: exit nonzero)" do
      Dir.mktmpdir("resolver") do |dir|
        root = write(dir, "mim.exp", mim_body)
        expect do
          described_class.closure_paths(root)
        end.to raise_error(Thor::Error, /m_arm.*--manifest/)
      end
    end

    it "raises when an explicitly given manifest cannot be loaded, even with no dependencies (#455)" do
      Dir.mktmpdir("resolver") do |dir|
        root = write(dir, "plain.exp", "SCHEMA plain;\nENTITY e; x : STRING; END_ENTITY;\nEND_SCHEMA;\n")
        expect do
          described_class.closure_paths(root, manifest: File.join(dir, "missing.yaml"))
        end.to raise_error(Thor::Error, /could not load schema manifest .*missing\.yaml/)
      end
    end

    it "prefers a same-directory declaration over an enclosing schemas/ tree (#455)" do
      Dir.mktmpdir("resolver") do |dir|
        schemas = File.join(dir, "schemas")
        local = File.join(schemas, "sub")
        FileUtils.mkdir_p(local)
        # The tree's m_arm is found by declared name; the local file
        # provides m_arm through its basename, so the two indexes
        # genuinely disagree on which path m_arm resolves to.
        tree_arm = write(schemas, "m_arm.exp", arm_body)
        local_arm = write(local, "m_arm.exp", <<~EXP)
          SCHEMA m_zebra;
          ENTITY local_marker; b : STRING; END_ENTITY;
          END_SCHEMA;
        EXP
        root = write(local, "mim.exp", mim_body)

        paths = described_class.closure_paths(root)
        aggregate_failures do
          expect(paths).to include(local_arm)
          expect(paths).not_to include(tree_arm)
        end
      end
    end
  end

  describe ".root_schema" do
    it "parses the root schema without resolving references" do
      Dir.mktmpdir("resolver") do |dir|
        root = write(dir, "solo.exp", "SCHEMA solo;\nENTITY e; x : STRING; END_ENTITY;\nEND_SCHEMA;\n")
        root_schema, repo = described_class.root_schema(root)
        aggregate_failures do
          expect(root_schema.id).to eq("solo")
          expect(repo.files.first.schemas.first.id).to eq("solo")
        end
      end
    end
  end
end
