require "spec_helper"

RSpec.describe Expressir::Coverage do
  describe ".entity_documented?" do
    it "returns true for an entity with direct remarks" do
      # Create a test entity with remarks
      entity = Expressir::Model::Declarations::Entity.new(
        id: "test_entity",
        remarks: ["This is a test remark"],
      )

      expect(described_class.entity_documented?(entity)).to be true
    end

    it "returns false for an entity without remarks" do
      # Create a test entity without remarks
      entity = Expressir::Model::Declarations::Entity.new(
        id: "test_entity",
      )

      expect(described_class.entity_documented?(entity)).to be false
    end

    it "returns true for an entity with empty remarks array but has remark items" do
      # Create a test entity with remark items
      entity = Expressir::Model::Declarations::Entity.new(
        id: "test_entity",
        remarks: [],
        remark_items: [
          Expressir::Model::Declarations::RemarkItem.new(
            id: "test_entity",
            remarks: ["This is a remark item"],
          ),
        ],
      )

      expect(described_class.entity_documented?(entity)).to be true
    end
  end

  describe ".find_entities" do
    let(:sample_schema_path) { File.join("spec", "syntax", "syntax.exp") }
    let(:repository) do
      Expressir::Express::Parser.from_file(sample_schema_path)
    end

    it "finds all entity types in a schema" do
      entities = described_class.find_entities(repository)

      # Should find various entity types
      entity_types = entities.map do |e|
        e.class.name.split("::").last
      end.uniq.sort

      expect(entity_types).to include("Entity")
      expect(entity_types).to include("Type")
      expect(entity_types).to include("Function")
      expect(entity_types).to include("Procedure")
      expect(entity_types).to include("Constant")
      expect(entity_types).to include("Rule")
      expect(entity_types).to include("Attribute")
      expect(entity_types).to include("Parameter")
      expect(entity_types).to include("Variable")
      expect(entity_types).to include("EnumerationItem")
      expect(entity_types).to include("WhereRule")
      expect(entity_types).to include("UniqueRule")
    end

    it "finds nested entities within functions" do
      entities = described_class.find_entities(repository)

      # Should find parameters and variables within functions
      parameters = entities.grep(Expressir::Model::Declarations::Parameter)
      variables = entities.grep(Expressir::Model::Declarations::Variable)

      expect(parameters).not_to be_empty
      expect(variables).not_to be_empty
    end

    it "finds nested entities within entities" do
      entities = described_class.find_entities(repository)

      # Should find attributes, unique rules, where rules within entities
      attributes = entities.grep(Expressir::Model::Declarations::Attribute)
      where_rules = entities.grep(Expressir::Model::Declarations::WhereRule)
      unique_rules = entities.grep(Expressir::Model::Declarations::UniqueRule)

      expect(attributes).not_to be_empty
      expect(where_rules).not_to be_empty
      expect(unique_rules).not_to be_empty
    end

    it "finds enumeration items within types" do
      entities = described_class.find_entities(repository)

      # Should find enumeration items within enumeration types
      enum_items = entities.grep(Expressir::Model::DataTypes::EnumerationItem)

      expect(enum_items).not_to be_empty
    end
  end

  describe ".apply_exclusions" do
    let(:sample_schema_path) { File.join("spec", "syntax", "syntax.exp") }
    let(:repository) do
      Expressir::Express::Parser.from_file(sample_schema_path)
    end
    let(:all_entities) { described_class.find_entities(repository) }

    it "excludes specified entity types" do
      exclusions = ["PARAMETER", "VARIABLE"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should not contain any parameters or variables
      expect(filtered_entities.any?(Expressir::Model::Declarations::Parameter)).to be false
      expect(filtered_entities.any?(Expressir::Model::Declarations::Variable)).to be false

      # Should still contain other types
      expect(filtered_entities.any?(Expressir::Model::Declarations::Entity)).to be true
      expect(filtered_entities.any?(Expressir::Model::Declarations::Type)).to be true
    end

    it "excludes TYPE subtypes" do
      exclusions = ["TYPE:SELECT"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should exclude SELECT types but keep other types
      select_types = filtered_entities.select do |e|
        e.is_a?(Expressir::Model::Declarations::Type) &&
          e.underlying_type.is_a?(Expressir::Model::DataTypes::Select)
      end

      expect(select_types).to be_empty

      # Should still contain non-SELECT types
      non_select_types = filtered_entities.select do |e|
        e.is_a?(Expressir::Model::Declarations::Type) &&
          !e.underlying_type.is_a?(Expressir::Model::DataTypes::Select)
      end

      expect(non_select_types).not_to be_empty
    end

    it "excludes multiple TYPE subtypes" do
      exclusions = ["TYPE:SELECT", "TYPE:ENUMERATION"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should exclude both SELECT and ENUMERATION types
      select_types = filtered_entities.select do |e|
        e.is_a?(Expressir::Model::Declarations::Type) &&
          e.underlying_type.is_a?(Expressir::Model::DataTypes::Select)
      end

      enum_types = filtered_entities.select do |e|
        e.is_a?(Expressir::Model::Declarations::Type) &&
          e.underlying_type.is_a?(Expressir::Model::DataTypes::Enumeration)
      end

      expect(select_types).to be_empty
      expect(enum_types).to be_empty
    end

    it "handles mixed exclusions" do
      exclusions = ["PARAMETER", "TYPE:SELECT", "VARIABLE"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should exclude parameters, variables, and SELECT types
      expect(filtered_entities.any?(Expressir::Model::Declarations::Parameter)).to be false
      expect(filtered_entities.any?(Expressir::Model::Declarations::Variable)).to be false

      select_types = filtered_entities.select do |e|
        e.is_a?(Expressir::Model::Declarations::Type) &&
          e.underlying_type.is_a?(Expressir::Model::DataTypes::Select)
      end
      expect(select_types).to be_empty
    end

    it "returns all entities when no exclusions specified" do
      filtered_entities = described_class.apply_exclusions(all_entities, [])

      expect(filtered_entities.size).to eq(all_entities.size)
    end

    it "excludes inner functions with FUNCTION:INNER" do
      nested_schema_path = File.join("spec", "fixtures", "examples",
                                     "nested_functions_test_schema.exp")
      repository = Expressir::Express::Parser.from_file(nested_schema_path)
      all_entities = described_class.find_entities(repository)

      exclusions = ["FUNCTION:INNER"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should exclude inner functions but keep top-level functions
      all_functions = all_entities.grep(Expressir::Model::Declarations::Function)
      filtered_functions = filtered_entities.grep(Expressir::Model::Declarations::Function)

      # Should have fewer functions after filtering
      expect(filtered_functions.size).to be < all_functions.size

      # Should only contain top-level functions
      top_level_function_names = filtered_functions.map(&:id).map(&:to_s)
      expect(top_level_function_names).to include("top_level_function")
      expect(top_level_function_names).to include("another_top_level_function")
      expect(top_level_function_names).not_to include("inner_function_in_function")
      expect(top_level_function_names).not_to include("deeply_nested_function")
      expect(top_level_function_names).not_to include("inner_function_in_rule")
      expect(top_level_function_names).not_to include("inner_function_in_procedure")
      expect(top_level_function_names).not_to include("nested_in_procedure_function")
    end

    it "handles mixed exclusions including FUNCTION:INNER" do
      nested_schema_path = File.join("spec", "fixtures", "examples",
                                     "nested_functions_test_schema.exp")
      repository = Expressir::Express::Parser.from_file(nested_schema_path)
      all_entities = described_class.find_entities(repository)

      exclusions = ["PARAMETER", "FUNCTION:INNER", "VARIABLE"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should exclude parameters, variables, and inner functions
      expect(filtered_entities.any?(Expressir::Model::Declarations::Parameter)).to be false
      expect(filtered_entities.any?(Expressir::Model::Declarations::Variable)).to be false

      # Should exclude inner functions but keep top-level functions
      filtered_functions = filtered_entities.grep(Expressir::Model::Declarations::Function)
      top_level_function_names = filtered_functions.map(&:id).map(&:to_s)
      expect(top_level_function_names).to include("top_level_function")
      expect(top_level_function_names).to include("another_top_level_function")
      expect(top_level_function_names).not_to include("inner_function_in_function")
      expect(top_level_function_names).not_to include("inner_function_in_rule")
      expect(top_level_function_names).not_to include("inner_function_in_procedure")
    end

    it "handles invalid exclusion patterns gracefully" do
      exclusions = ["INVALID_TYPE", "TYPE:INVALID_SUBTYPE",
                    "FUNCTION:INVALID_SUBTYPE"]
      filtered_entities = described_class.apply_exclusions(all_entities,
                                                           exclusions)

      # Should return all entities since invalid exclusions don't match anything
      expect(filtered_entities.size).to eq(all_entities.size)
    end
  end

  describe "Report" do
    let(:sample_schema_path) { File.join("spec", "syntax", "remark.exp") }

    context "with a single file" do
      it "creates a report from a file" do
        report = Expressir::Coverage::Report.from_file(sample_schema_path)

        expect(report).to be_a(Expressir::Coverage::Report)
        expect(report.total_entities).not_to be_empty
        expect(report.file_reports).not_to be_empty
      end

      it "calculates coverage percentage" do
        report = Expressir::Coverage::Report.from_file(sample_schema_path)

        expect(report.coverage_percentage).to be_a(Float)
        expect(report.coverage_percentage).to be_between(0, 100)
      end

      it "applies exclusions when specified" do
        report_without_exclusions = Expressir::Coverage::Report.from_file(sample_schema_path)
        report_with_exclusions = Expressir::Coverage::Report.from_file(
          sample_schema_path, exclusions: ["PARAMETER", "VARIABLE"]
        )

        expect(report_with_exclusions.total_entities.size).to be <= report_without_exclusions.total_entities.size
      end
    end

    context "with a repository" do
      let(:repository) do
        Expressir::Express::Parser.from_file(sample_schema_path)
      end

      it "creates a report from a repository" do
        report = Expressir::Coverage::Report.from_repository(repository)

        expect(report).to be_a(Expressir::Coverage::Report)
        expect(report.repository).to eq(repository)
      end

      it "processes all schemas in the repository" do
        report = Expressir::Coverage::Report.from_repository(repository)

        expect(report.schema_reports.size).to eq(repository.schemas.size)
      end

      it "applies exclusions when specified" do
        report_without_exclusions = Expressir::Coverage::Report.from_repository(repository)
        report_with_exclusions = Expressir::Coverage::Report.from_repository(
          repository, exclusions: ["PARAMETER", "VARIABLE"]
        )

        expect(report_with_exclusions.total_entities.size).to be <= report_without_exclusions.total_entities.size
      end
    end

    context "with comprehensive entity detection" do
      let(:syntax_schema_path) { File.join("spec", "syntax", "syntax.exp") }
      let(:report) { Expressir::Coverage::Report.from_file(syntax_schema_path) }

      it "detects all major entity types" do
        entity_types = report.total_entities.map do |e|
          e.class.name.split("::").last
        end.uniq.sort

        # Should detect all major EXPRESS entity types
        expected_types = %w[
          Attribute Constant DerivedAttribute Entity EnumerationItem Function
          InverseAttribute Parameter Procedure Rule SubtypeConstraint Type
          UniqueRule Variable WhereRule
        ]

        # Check that we find most of the expected types (some may not be present in test file)
        found_expected = expected_types & entity_types
        expect(found_expected.size).to be >= 8 # Should find at least 8 of the major types
      end

      it "provides detailed entity information in reports" do
        expect(report.file_reports).not_to be_empty

        file_report = report.file_reports.first
        expect(file_report).to have_key("total")
        expect(file_report).to have_key("documented")
        expect(file_report).to have_key("undocumented")
        expect(file_report).to have_key("coverage")

        if file_report["undocumented"].any?
          undocumented_item = file_report["undocumented"].first
          expect(undocumented_item).to have_key("type")
          expect(undocumented_item).to have_key("name")
        end
      end
    end
  end
end
