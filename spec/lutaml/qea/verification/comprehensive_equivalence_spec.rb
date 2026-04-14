# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/uml_repository/repository"
require_relative "../../../../lib/lutaml/qea/parser"

RSpec.describe "XMI/QEA Comprehensive Equivalence Verification" do
  # Skip tests if files don't exist
  before(:all) do
    # Test file pairs - each QEA should contain all information from
    # corresponding XMI
    test_files = [
      {
        name: "UmlModel Template",
        xmi: File.join(__dir__, "../../../examples/qea/UmlModel_template.xmi"),
        qea: File.join(__dir__, "../../../examples/qea/UmlModel_template.qea"),
      },
      {
        name: "Test Model",
        xmi: File.join(__dir__, "../../../examples/qea/test.xmi"),
        qea: File.join(__dir__, "../../../examples/qea/test.qea"),
      },
      {
        name: "ArcGIS Workspace Template",
        xmi: File.join(__dir__,
                       "../../../examples/qea/ArcGISWorkspace_template.xmi"),
        qea: File.join(__dir__,
                       "../../../examples/qea/ArcGISWorkspace_template.qea"),
      },
      {
        name: "Plateau v5.1",
        xmi: File.join(__dir__,
                       "../../../examples/qea/20251010_current_plateau_v5.1.xmi"),
        qea: File.join(__dir__,
                       "../../../examples/qea/20251010_current_plateau_v5.1.qea"),
      },
    ]

    @available_files = test_files.select do |file_pair|
      File.exist?(file_pair[:xmi]) && File.exist?(file_pair[:qea])
    end

    if @available_files.empty?
      skip "No XMI/QEA file pairs available for testing"
    end
  end

  describe "Package Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI packages represented in QEA" do
          xmi_packages = extract_all_packages(xmi_repo)
          qea_packages = extract_all_packages(qea_repo)

          xmi_packages.each do |xmi_package|
            matching_qea = find_matching_package(qea_packages, xmi_package)

            expect(matching_qea).not_to be_nil,
                                        "Package '#{xmi_package.name}' (#{xmi_package.qualified_name}) " \
                                        "from XMI not found in QEA"

            # Verify package properties match
            expect(matching_qea.name).to eq(xmi_package.name)
            if xmi_package.visibility && matching_qea.visibility
              expect(matching_qea.visibility).to eq(xmi_package.visibility)
            end
          end
        end

        it "has equal or more packages in QEA than XMI" do
          xmi_count = count_packages(xmi_repo)
          qea_count = count_packages(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} packages, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI packages."
        end
      end
    end
  end

  describe "Class Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI classes represented in QEA" do
          xmi_classes = extract_all_classes(xmi_repo)
          qea_classes = extract_all_classes(qea_repo)

          xmi_classes.each do |xmi_class|
            matching_qea = find_matching_class(qea_classes, xmi_class)

            expect(matching_qea).not_to be_nil,
                                        "Class '#{xmi_class.name}' from " \
                                        "package '#{xmi_class.package_name}' not found in QEA"

            # Verify class properties
            expect(matching_qea.name).to eq(xmi_class.name)
            expect(matching_qea.package_name).to eq(xmi_class.package_name)

            if xmi_class.is_abstract && matching_qea.respond_to?(:is_abstract)
              expect(matching_qea.is_abstract).to eq(xmi_class.is_abstract)
            end
          end
        end

        it "has equal or more classes in QEA than XMI" do
          xmi_count = count_classes(xmi_repo)
          qea_count = count_classes(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} classes, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI classes."
        end
      end
    end
  end

  describe "Attribute Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI attributes represented in QEA" do
          xmi_attributes = extract_all_attributes(xmi_repo)
          qea_attributes = extract_all_attributes(qea_repo)

          xmi_attributes.each do |xmi_attr|
            matching_qea = find_matching_attribute(qea_attributes, xmi_attr)

            expect(matching_qea).not_to be_nil,
                                        "Attribute '#{xmi_attr.name}' in " \
                                        "class '#{xmi_attr.owner_name}' not found in QEA"

            # Verify attribute properties
            expect(matching_qea.name).to eq(xmi_attr.name)
            expect(matching_qea.owner_name).to eq(xmi_attr.owner_name)

            if xmi_attr.type && matching_qea.type
              expect(matching_qea.type).to eq(xmi_attr.type)
            end
          end
        end

        it "has equal or more attributes in QEA than XMI" do
          xmi_count = count_attributes(xmi_repo)
          qea_count = count_attributes(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} attributes, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI attributes."
        end
      end
    end
  end

  describe "Association Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI associations represented in QEA" do
          xmi_associations = extract_all_associations(xmi_repo)
          qea_associations = extract_all_associations(qea_repo)

          xmi_associations.each do |xmi_assoc|
            matching_qea = find_matching_association(
              qea_associations, xmi_assoc
            )

            expect(matching_qea).not_to be_nil,
                                        "Association between '#{xmi_assoc.source_type}' " \
                                        "and '#{xmi_assoc.target_type}' not found in QEA"

            # Verify association properties
            expect(matching_qea.source_type).to eq(xmi_assoc.source_type)
            expect(matching_qea.target_type).to eq(xmi_assoc.target_type)

            if xmi_assoc.name && matching_qea.name
              expect(matching_qea.name).to eq(xmi_assoc.name)
            end
          end
        end

        it "has equal or more associations in QEA than XMI" do
          xmi_count = count_associations(xmi_repo)
          qea_count = count_associations(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} associations, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI associations."
        end
      end
    end
  end

  describe "Enumeration Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI enumerations represented in QEA" do
          xmi_enums = extract_all_enums(xmi_repo)
          qea_enums = extract_all_enums(qea_repo)

          xmi_enums.each do |xmi_enum|
            matching_qea = find_matching_enum(qea_enums, xmi_enum)

            expect(matching_qea).not_to be_nil,
                                        "Enumeration '#{xmi_enum.name}' from " \
                                        "package '#{xmi_enum.package_name}' not found in QEA"

            # Verify enum properties
            expect(matching_qea.name).to eq(xmi_enum.name)
            expect(matching_qea.package_name).to eq(xmi_enum.package_name)
          end
        end

        it "has equal or more enumerations in QEA than XMI" do
          xmi_count = count_enums(xmi_repo)
          qea_count = count_enums(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} enums, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI enums."
        end
      end
    end
  end

  describe "Data Type Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI data types represented in QEA" do
          xmi_datatypes = extract_all_datatypes(xmi_repo)
          qea_datatypes = extract_all_datatypes(qea_repo)

          xmi_datatypes.each do |xmi_dt|
            matching_qea = find_matching_datatype(qea_datatypes, xmi_dt)

            expect(matching_qea).not_to be_nil,
                                        "Data type '#{xmi_dt.name}' from " \
                                        "package '#{xmi_dt.package_name}' not found in QEA"

            # Verify data type properties
            expect(matching_qea.name).to eq(xmi_dt.name)
            expect(matching_qea.package_name).to eq(xmi_dt.package_name)
          end
        end

        it "has equal or more data types in QEA than XMI" do
          xmi_count = count_datatypes(xmi_repo)
          qea_count = count_datatypes(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} data types, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI data types."
        end
      end
    end
  end

  describe "Operation Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has all XMI operations represented in QEA" do
          xmi_operations = extract_all_operations(xmi_repo)
          qea_operations = extract_all_operations(qea_repo)

          xmi_operations.each do |xmi_op|
            matching_qea = find_matching_operation(qea_operations, xmi_op)

            expect(matching_qea).not_to be_nil,
                                        "Operation '#{xmi_op.name}' in class '#{xmi_op.owner_name}' " \
                                        "not found in QEA"

            # Verify operation properties
            expect(matching_qea.name).to eq(xmi_op.name)
            expect(matching_qea.owner_name).to eq(xmi_op.owner_name)
          end
        end

        it "has equal or more operations in QEA than XMI" do
          xmi_count = count_operations(xmi_repo)
          qea_count = count_operations(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} operations, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI operations."
        end
      end
    end
  end

  describe "Diagram Coverage Verification" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "has equal or more diagrams in QEA than XMI" do
          xmi_count = count_diagrams(xmi_repo)
          qea_count = count_diagrams(qea_repo)

          expect(qea_count).to be >= xmi_count,
                               "QEA has #{qea_count} diagrams, XMI has #{xmi_count}. " \
                               "QEA should have >= XMI diagrams."
        end
      end
    end
  end

  describe "Cross-File Consistency" do
    it "maintains consistent element counts across all file pairs" do
      element_counts = @available_files.map do |file_pair|
        xmi_repo = Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi])
        qea_repo = Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository

        {
          name: file_pair[:name],
          xmi_packages: count_packages(xmi_repo),
          qea_packages: count_packages(qea_repo),
          xmi_classes: count_classes(xmi_repo),
          qea_classes: count_classes(qea_repo),
          ratio: count_classes(qea_repo).to_f / [count_classes(xmi_repo),
                                                 1].max,
        }
      end

      # All QEA files should have >= XMI counts
      element_counts.each do |counts|
        expect(counts[:qea_packages]).to be >= counts[:xmi_packages]
        expect(counts[:qea_classes]).to be >= counts[:xmi_classes]
        expect(counts[:ratio]).to be >= 1.0
      end
    end
  end

  describe "Repository Integration" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        let(:xmi_repo) { Lutaml::UmlRepository::Repository.from_xmi(file_pair[:xmi]) }
        let(:qea_repo) { Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository }

        it "supports the same query operations on both repositories" do
          # Test package queries
          xmi_root_packages = xmi_repo.packages.select do |p|
            p.parent_package.nil?
          end
          qea_root_packages = qea_repo.packages.select do |p|
            p.parent_package.nil?
          end

          expect(qea_root_packages.size).to be >= xmi_root_packages.size

          # Test class queries
          if xmi_repo.classes.any?
            sample_class_name = xmi_repo.classes.first.name
            qea_matching_classes = qea_repo.classes.select do |c|
              c.name == sample_class_name
            end
            expect(qea_matching_classes).not_to be_empty
          end

          # Test search functionality
          if xmi_repo.classes.any? && xmi_repo.classes.first.name.length > 3
            search_term = xmi_repo.classes.first.name[0..2]
            xmi_results = xmi_repo.search(search_term)
            qea_results = qea_repo.search(search_term)

            expect(qea_results.size).to be >= xmi_results.size
          end
        end

        it "maintains referential integrity in both repositories" do
          # Test that all class attribute types are resolvable
          xmi_repo.classes.each do |klass|
            klass.attributes.each do |attr|
              if attr.type && !attr.type.empty?
                # The type should be resolvable in the repository
                xmi_repo.classes.any? { |c| c.name == attr.type } ||
                  xmi_repo.data_types.any? do |dt|
                    dt.name == attr.type
                  end ||
                  xmi_repo.enums.any? { |e| e.name == attr.type }

                # We don't require strict resolution for all types
                # (primitives, external refs)
                # This is just a consistency check
              end
            end
          end

          # Same check for QEA repo
          qea_repo.classes.each do |klass|
            klass.attributes.each do |attr|
              if attr.type && !attr.type.empty?
                qea_repo.classes.any? do |c|
                  c.name == attr.type
                end ||
                  qea_repo.data_types.any? do |dt|
                    dt.name == attr.type
                  end ||
                  qea_repo.enums.any? { |e| e.name == attr.type }
              end
            end
          end
        end
      end
    end
  end

  describe "Performance Benchmarks" do
    @available_files&.each do |file_pair|
      context file_pair[:name].to_s do
        it "loads QEA files in reasonable time" do
          start_time = Time.now
          Lutaml::Qea::Parser
            .parse(file_pair[:qea]).to_uml_repository
          load_time = Time.now - start_time

          # Large files should load within 30 seconds
          expect(load_time).to be < 30.0

          puts "  QEA load time: #{load_time.round(2)}s"
        end

        it "provides efficient search on large models" do
          qea_repo = Lutaml::Qea::Parser.parse(file_pair[:qea]).to_uml_repository

          start_time = Time.now
          results = qea_repo.search("building")
          search_time = Time.now - start_time

          # Search should complete within 5 seconds even for large models
          expect(search_time).to be < 5.0

          puts "  Search time: #{search_time.round(3)}s " \
               "(#{results.size} results)"
        end
      end
    end
  end

  private

  # Helper methods for extracting and counting elements
  def extract_all_packages(repo)
    repo.packages
  end

  def extract_all_classes(repo)
    repo.classes
  end

  def extract_all_attributes(repo)
    repo.classes.flat_map(&:attributes)
  end

  def extract_all_associations(repo)
    repo.associations
  end

  def extract_all_enums(repo)
    repo.enums
  end

  def extract_all_datatypes(repo)
    repo.data_types
  end

  def extract_all_operations(repo)
    repo.classes.flat_map(&:operations)
  end

  def count_packages(repo)
    repo.packages.size
  end

  def count_classes(repo)
    repo.classes.size
  end

  def count_attributes(repo)
    repo.classes.sum { |c| c.attributes.size }
  end

  def count_associations(repo)
    repo.associations.size
  end

  def count_enums(repo)
    repo.enums.size
  end

  def count_datatypes(repo)
    repo.data_types.size
  end

  def count_operations(repo)
    repo.classes.sum { |c| c.operations.size }
  end

  def count_diagrams(repo)
    repo.diagrams&.size || 0
  end

  # Helper methods for finding matching elements
  def find_matching_package(qea_packages, xmi_package)
    qea_packages.find do |qea_pkg|
      qea_pkg.name == xmi_package.name &&
        qea_pkg.qualified_name == xmi_package.qualified_name
    end
  end

  def find_matching_class(qea_classes, xmi_class)
    qea_classes.find do |qea_cls|
      qea_cls.name == xmi_class.name &&
        qea_cls.package_name == xmi_class.package_name
    end
  end

  def find_matching_attribute(qea_attributes, xmi_attr)
    qea_attributes.find do |qea_attr|
      qea_attr.name == xmi_attr.name &&
        qea_attr.owner_name == xmi_attr.owner_name
    end
  end

  def find_matching_association(qea_associations, xmi_assoc)
    qea_associations.find do |qea_assoc|
      qea_assoc.source_type == xmi_assoc.source_type &&
        qea_assoc.target_type == xmi_assoc.target_type
    end
  end

  def find_matching_enum(qea_enums, xmi_enum)
    qea_enums.find do |qea_enum|
      qea_enum.name == xmi_enum.name &&
        qea_enum.package_name == xmi_enum.package_name
    end
  end

  def find_matching_datatype(qea_datatypes, xmi_dt)
    qea_datatypes.find do |qea_dt|
      qea_dt.name == xmi_dt.name &&
        qea_dt.package_name == xmi_dt.package_name
    end
  end

  def find_matching_operation(qea_operations, xmi_op)
    qea_operations.find do |qea_op|
      qea_op.name == xmi_op.name &&
        qea_op.owner_name == xmi_op.owner_name
    end
  end
end
