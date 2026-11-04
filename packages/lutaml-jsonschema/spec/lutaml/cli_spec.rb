# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Lutaml::Jsonschema::Cli do
  let(:fixtures_dir) { File.expand_path("../fixtures", __dir__) }
  let(:person_schema) { File.join(fixtures_dir, "person.json") }
  let(:user_schema) { File.join(fixtures_dir, "user.json") }
  let(:post_schema) { File.join(fixtures_dir, "post.json") }

  describe "spa" do
    it "generates SPA documentation" do
      Dir.mktmpdir do |dir|
        described_class.start(["spa", person_schema, "-o", dir])
        output = File.join(dir, "index.html")
        expect(File.exist?(output)).to be true
        html = File.read(output)
        expect(html).to include("window.SCHEMA_DATA")
        expect(html).to include("<!DOCTYPE html>")
      end
    end

    it "generates with custom title" do
      Dir.mktmpdir do |dir|
        described_class.start(["spa", person_schema, "-o", dir, "--title",
                               "My Docs"])
        html = File.read(File.join(dir, "index.html"))
        expect(html).to include("My Docs")
      end
    end

    it "generates from multiple schema files" do
      Dir.mktmpdir do |dir|
        described_class.start(["spa", person_schema, user_schema, post_schema,
                               "-o", dir])
        html = File.read(File.join(dir, "index.html"))
        expect(html).to include("person")
        expect(html).to include("user")
        expect(html).to include("post")
      end
    end

    it "reports changes against a baseline schema" do
      Dir.mktmpdir do |dir|
        baseline_hash = Yeptris::JSON.load(File.read(person_schema))
        baseline_hash["properties"]["golden_removed"] = { "type" => "string" }
        baseline = File.join(dir, "person.json")
        File.write(baseline, Yeptris::JSON.dump(baseline_hash))
        out = File.join(dir, "out")

        described_class.start(["spa", person_schema, "-o", out,
                               "--diff", baseline])
        html = File.read(File.join(out, "index.html"))

        expect(html).to include('"schemaName":"person"')
        expect(html).to include('"classification":"breaking"')
        expect(html).to include("golden_removed")
      end
    end

    it "raises error with no schema files" do
      expect do
        described_class.start(["spa"])
      end.to raise_error(Lutaml::Jsonschema::Error,
                         /No schema files/)
    end
  end

  describe "combine" do
    it "combines schemas to stdout" do
      expect { described_class.start(["combine", person_schema, user_schema]) }
        .to output(/"\$defs"/).to_stdout
    end

    it "accepts remote access flags" do
      expect { described_class.start(["combine", person_schema, "--remote"]) }
        .to output(/"\$defs"/).to_stdout
      expect do
        described_class.start(["combine", person_schema, "--remote-cache",
                               File.join(Dir.mktmpdir, "cache")])
      end.to output(/"\$defs"/).to_stdout
    end

    it "combines schemas to file" do
      Dir.mktmpdir do |dir|
        output = File.join(dir, "combined.json")
        described_class.start(["combine", person_schema, user_schema, "-o",
                               output])
        expect(File.exist?(output)).to be true
        json = JSON.parse(File.read(output))
        expect(json).to have_key("$defs")
      end
    end
  end

  describe "validate" do
    it "validates a valid schema" do
      expect { described_class.start(["validate", person_schema]) }
        .to output(/valid/).to_stdout
    end

    it "reports errors for invalid JSON" do
      Dir.mktmpdir do |dir|
        bad = File.join(dir, "bad.json")
        File.write(bad, "not json")
        expect { described_class.start(["validate", bad]) }
          .to raise_error(SystemExit)
      end
    end

    it "reports meta-schema errors with JSON pointers" do
      Dir.mktmpdir do |dir|
        bad = File.join(dir, "bad_schema.json")
        File.write(bad, '{"$schema":"http://json-schema.org/draft-07/schema#",' \
                        '"type":5}')

        expect do
          described_class.start(["validate", bad])
        rescue SystemExit
          nil
        end.to output(%r{/type:}).to_stderr
      end
    end

    it "emits machine-readable results with --format json" do
      expect do
        described_class.start(["validate", person_schema, "--format", "json"])
      end.to output(/"valid": true/).to_stdout
    end
  end

  describe "version" do
    it "prints the version" do
      expect { described_class.start(["version"]) }
        .to output(/lutaml-jsonschema #{Lutaml::Jsonschema::VERSION}/o).to_stdout
    end
  end
end
