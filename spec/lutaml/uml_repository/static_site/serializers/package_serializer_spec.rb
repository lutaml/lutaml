# frozen_string_literal: true

require "spec_helper"
require "lutaml/uml_repository"

RSpec.describe Lutaml::UmlRepository::StaticSite::Serializers::PackageSerializer do
  let(:document) { create_simple_test_document }
  let(:repository) { Lutaml::UmlRepository::Repository.new(document: document) }
  let(:id_generator) { Lutaml::UmlRepository::StaticSite::IdGenerator.new }
  let(:options) { { format_definitions: false, include_diagrams: true } }

  describe "#build_map" do
    it "returns a hash keyed by package ID" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      expect(result).to be_a(Hash)
      expect(result.size).to be >= 1

      result.each_key do |key|
        expect(key).to start_with("pkg_")
      end
    end

    it "produces typed SpaPackage with sub-packages" do
      serializer = described_class.new(repository, id_generator, options)
      result = serializer.build_map

      result.each_value do |spa_pkg|
        expect(spa_pkg).to be_a(Lutaml::UmlRepository::StaticSite::Models::SpaPackage)
        expect(spa_pkg.name).to be_a(String)
        expect(spa_pkg.sub_packages).to be_a(Array)
      end
    end

    it "sets parent ID on child packages when namespace chain exists" do
      doc = Lutaml::Uml::Document.new
      doc.name = "ParentChild"

      parent_pkg = Lutaml::Uml::Package.new
      parent_pkg.name = "Parent"
      parent_pkg.xmi_id = "pkg_parent"

      child_pkg = Lutaml::Uml::Package.new
      child_pkg.name = "Child"
      child_pkg.xmi_id = "pkg_child"
      child_pkg.namespace = parent_pkg

      parent_pkg.packages << child_pkg
      doc.packages << parent_pkg

      repo = Lutaml::UmlRepository::Repository.new(document: doc)
      serializer = described_class.new(repo, id_generator, options)
      result = serializer.build_map

      child_packages = result.values.select(&:parent)
      expect(child_packages.size).to eq(1)

      child_packages.each do |spa_pkg|
        expect(result).to have_key(spa_pkg.parent)
      end
    end

    it "builds qualified path using package hierarchy" do
      doc = Lutaml::Uml::Document.new
      doc.name = "Path"

      parent_pkg = Lutaml::Uml::Package.new
      parent_pkg.name = "Parent"
      parent_pkg.xmi_id = "pkg_parent"

      child_pkg = Lutaml::Uml::Package.new
      child_pkg.name = "Child"
      child_pkg.xmi_id = "pkg_child"
      child_pkg.namespace = parent_pkg

      parent_pkg.packages << child_pkg
      doc.packages << parent_pkg

      repo = Lutaml::UmlRepository::Repository.new(document: doc)
      serializer = described_class.new(repo, id_generator, options)
      result = serializer.build_map

      child_id = id_generator.package_id(child_pkg)
      spa_child = result[child_id]
      expect(spa_child.path).to include("::")
    end
  end
end
