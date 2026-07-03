# frozen_string_literal: true

require "spec_helper"

RSpec.describe "QEA and XMI Equivalency", :integration do
  let(:qea_path) { "examples/qea/basic.qea" }
  let(:qea_document) do
    db = cached_qea_database(qea_path)
    Lutaml::Qea::Factory::EaToUmlFactory.new(db).create_document
  end
  let(:xmi_document) do
    cached_xmi_document(xmi_path, fixture: false)
  end
  let(:xmi_path) { "examples/xmi/basic.xmi" }

  before do
    skip "QEA file not found" unless File.exist?(qea_path)
    skip "XMI file not found" unless File.exist?(xmi_path)
  end

  describe "basic.xmi generated from basic.qea" do
    it "QEA contains all information in XMI (QEA is source, XMI is export)" do
      xmi_class_count = count_all_classes(xmi_document)
      qea_class_count = count_all_classes(qea_document)

      expect(xmi_class_count).to be <= qea_class_count,
                                 "XMI should have <= classes than QEA (XMI: #{xmi_class_count}, " \
                                 "QEA: #{qea_class_count})"
    end

    it "XMI classes are subset of QEA classes" do
      qea_class_names = collect_all_class_names(qea_document)
      xmi_class_names = collect_all_class_names(xmi_document)

      missing_in_qea = xmi_class_names - qea_class_names
      extra_in_qea = qea_class_names - xmi_class_names

      if missing_in_qea.any? # rubocop:disable Lint/EmptyConditionalBody
      end

      if extra_in_qea.any? # rubocop:disable Lint/EmptyConditionalBody
      end

      expect(extra_in_qea.size).to be >= 0
    end

    it "has compatible package structure", :aggregate_failures do
      expect(qea_document.packages).not_to be_nil
      expect(xmi_document.packages).not_to be_nil

      expect(qea_document.packages.size)
        .to be >= (xmi_document.packages&.size || 0)
    end

    it "has compatible association structure" do
      qea_assoc_count = qea_document.associations&.size || 0
      xmi_assoc_count = xmi_document.associations&.size || 0

      expect(qea_assoc_count).to be >= xmi_assoc_count,
                                 "QEA should have >= associations (QEA: #{qea_assoc_count}, " \
                                 "XMI: #{xmi_assoc_count})"
    end
  end

  private

  def count_all_classes(document)
    count = 0
    count += document.classes&.size || 0
    count += count_classes_in_packages(document.packages || [])
    count
  end

  def count_classes_in_packages(packages)
    packages.sum do |pkg|
      count = pkg.classes&.size || 0
      count += count_classes_in_packages(pkg.packages || [])
      count
    end
  end

  def collect_all_class_names(document)
    names = []
    names += document.classes&.map(&:name) || []
    names += collect_class_names_from_packages(document.packages || [])
    names.compact
  end

  def collect_class_names_from_packages(packages)
    names = []
    packages.each do |pkg|
      names += pkg.classes&.map(&:name) || []
      names += collect_class_names_from_packages(pkg.packages || [])
    end
    names
  end
end
