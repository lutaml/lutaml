# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "../scripts/monorepo"

RSpec.describe Monorepo do
  def write_package(root, name, version, style: :relative)
    dir = File.join(root, "packages", name)
    FileUtils.mkdir_p(File.join(dir, "lib", name.tr("-", "/")))
    version_path = "lib/#{name.tr('-', '/')}/version"
    File.write("#{dir}/#{version_path}.rb", "module X\n  VERSION = \"#{version}\"\nend\n")
    requirement = style == :relative ? %(require_relative "#{version_path}") : %(require "#{name.tr('-', '/')}/version")
    File.write(File.join(dir, "#{name}.gemspec"), "#{requirement}\n")
  end

  let(:root) { Dir.mktmpdir }

  before do
    write_package(root, "alpha", "1.2.3")
    write_package(root, "alpha-beta", "0.8.9", style: :plain)
    FileUtils.mkdir_p(File.join(root, "packages", "not-a-gem"))
  end

  after { FileUtils.remove_entry(root) }

  it "lists only directories holding a matching gemspec" do
    expect(described_class.packages(root)).to eq(%w[alpha alpha-beta])
  end

  it "reads versions for both require styles" do
    expect([described_class.version("alpha", root), described_class.version("alpha-beta", root)])
      .to eq(%w[1.2.3 0.8.9])
  end

  it "resolves a tag to the longest package prefix" do
    expect(described_class.package_of("alpha-beta-v0.8.9", root)).to eq("alpha-beta")
    expect(described_class.package_of("alpha-v1.2.3", root)).to eq("alpha")
  end

  it "rejects a tag with no package prefix" do
    expect { described_class.package_of("v1.0.0", root) }.to raise_error(Monorepo::Error, /no package/)
  end

  it "rejects a tag whose version differs from the gemspec" do
    expect { described_class.check_tag("alpha-v9.9.9", root) }
      .to raise_error(Monorepo::Error, /expected alpha-v1.2.3/)
    expect(described_class.check_tag("alpha-v1.2.3", root)).to eq("alpha")
  end

  it "rejects an unknown package" do
    expect { described_class.version("nope", root) }.to raise_error(Monorepo::Error, /unknown package/)
  end

  describe ".bump" do
    it "bumps only the named package" do
      expect(described_class.bump("alpha", "minor", root)).to eq("1.3.0")
      expect(described_class.version("alpha", root)).to eq("1.3.0")
      expect(described_class.version("alpha-beta", root)).to eq("0.8.9")
    end

    it "accepts patch, major and explicit versions" do
      expect(described_class.bump("alpha", "patch", root)).to eq("1.2.4")
      expect(described_class.bump("alpha", "major", root)).to eq("2.0.0")
      expect(described_class.bump("alpha", "3.0.0.rc1", root)).to eq("3.0.0.rc1")
    end

    it "rejects a malformed request" do
      expect { described_class.bump("alpha", "bigger", root) }.to raise_error(Monorepo::Error, /bad version/)
    end
  end

  describe "the real packages" do
    it "give every package a unique, self-consistent tag" do
      tags = described_class.packages.map { |name| described_class.tag(name) }
      expect(described_class.packages)
        .to include("lutaml", "lutaml-model", "lutaml-xsd", "lutaml-jsonschema", "expressir", "lutaml-graphviz")
      expect(tags.uniq).to eq(tags)
      tags.each { |t| expect(described_class.check_tag(t)).to eq(described_class.package_of(t)) }
    end
  end
end
