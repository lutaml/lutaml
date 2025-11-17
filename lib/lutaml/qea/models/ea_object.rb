# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents an object from the t_object table in EA database
      # This is the core entity representing classes, interfaces, components, etc.
      class EaObject < BaseModel
        attribute :ea_object_id, Lutaml::Model::Type::Integer
        attribute :object_type, Lutaml::Model::Type::String
        attribute :diagram_id, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :alias, Lutaml::Model::Type::String
        attribute :author, Lutaml::Model::Type::String
        attribute :version, Lutaml::Model::Type::String
        attribute :note, Lutaml::Model::Type::String
        attribute :package_id, Lutaml::Model::Type::Integer
        attribute :stereotype, Lutaml::Model::Type::String
        attribute :ntype, Lutaml::Model::Type::Integer
        attribute :complexity, Lutaml::Model::Type::String
        attribute :effort, Lutaml::Model::Type::Integer
        attribute :style, Lutaml::Model::Type::String
        attribute :backcolor, Lutaml::Model::Type::Integer
        attribute :borderstyle, Lutaml::Model::Type::Integer
        attribute :borderwidth, Lutaml::Model::Type::Integer
        attribute :fontcolor, Lutaml::Model::Type::Integer
        attribute :bordercolor, Lutaml::Model::Type::Integer
        attribute :createddate, Lutaml::Model::Type::String
        attribute :modifieddate, Lutaml::Model::Type::String
        attribute :status, Lutaml::Model::Type::String
        attribute :abstract, Lutaml::Model::Type::String
        attribute :tagged, Lutaml::Model::Type::Integer
        attribute :pdata1, Lutaml::Model::Type::String
        attribute :pdata2, Lutaml::Model::Type::String
        attribute :pdata3, Lutaml::Model::Type::String
        attribute :pdata4, Lutaml::Model::Type::String
        attribute :pdata5, Lutaml::Model::Type::String
        attribute :concurrency, Lutaml::Model::Type::String
        attribute :visibility, Lutaml::Model::Type::String
        attribute :persistence, Lutaml::Model::Type::String
        attribute :cardinality, Lutaml::Model::Type::String
        attribute :gentype, Lutaml::Model::Type::String
        attribute :genfile, Lutaml::Model::Type::String
        attribute :header1, Lutaml::Model::Type::String
        attribute :header2, Lutaml::Model::Type::String
        attribute :phase, Lutaml::Model::Type::String
        attribute :scope, Lutaml::Model::Type::String
        attribute :genoption, Lutaml::Model::Type::String
        attribute :genlinks, Lutaml::Model::Type::String
        attribute :classifier, Lutaml::Model::Type::Integer
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :parentid, Lutaml::Model::Type::Integer
        attribute :runstate, Lutaml::Model::Type::String
        attribute :classifier_guid, Lutaml::Model::Type::String
        attribute :tpos, Lutaml::Model::Type::Integer
        attribute :isroot, Lutaml::Model::Type::Integer
        attribute :isleaf, Lutaml::Model::Type::Integer
        attribute :isspec, Lutaml::Model::Type::Integer
        attribute :isactive, Lutaml::Model::Type::Integer
        attribute :stateflags, Lutaml::Model::Type::String
        attribute :packageflags, Lutaml::Model::Type::String
        attribute :multiplicity, Lutaml::Model::Type::String
        attribute :styleex, Lutaml::Model::Type::String
        attribute :actionflags, Lutaml::Model::Type::String
        attribute :eventflags, Lutaml::Model::Type::String

        def self.primary_key_column
          :ea_object_id
        end

        def self.table_name
          "t_object"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaObject, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            ea_object_id: row["Object_ID"],
            object_type: row["Object_Type"],
            diagram_id: row["Diagram_ID"],
            name: row["Name"],
            alias: row["Alias"],
            author: row["Author"],
            version: row["Version"],
            note: row["Note"],
            package_id: row["Package_ID"],
            stereotype: row["Stereotype"],
            ntype: row["NType"],
            complexity: row["Complexity"],
            effort: row["Effort"],
            style: row["Style"],
            backcolor: row["BackColor"],
            borderstyle: row["BorderStyle"],
            borderwidth: row["BorderWidth"],
            fontcolor: row["Fontcolor"],
            bordercolor: row["Bordercolor"],
            createddate: row["CreatedDate"],
            modifieddate: row["ModifiedDate"],
            status: row["Status"],
            abstract: row["Abstract"],
            tagged: row["Tagged"],
            pdata1: row["PDATA1"],
            pdata2: row["PDATA2"],
            pdata3: row["PDATA3"],
            pdata4: row["PDATA4"],
            pdata5: row["PDATA5"],
            concurrency: row["Concurrency"],
            visibility: row["Visibility"],
            persistence: row["Persistence"],
            cardinality: row["Cardinality"],
            gentype: row["GenType"],
            genfile: row["GenFile"],
            header1: row["Header1"],
            header2: row["Header2"],
            phase: row["Phase"],
            scope: row["Scope"],
            genoption: row["GenOption"],
            genlinks: row["GenLinks"],
            classifier: row["Classifier"],
            ea_guid: row["ea_guid"],
            parentid: row["ParentID"],
            runstate: row["RunState"],
            classifier_guid: row["Classifier_guid"],
            tpos: row["TPos"],
            isroot: row["IsRoot"],
            isleaf: row["IsLeaf"],
            isspec: row["IsSpec"],
            isactive: row["IsActive"],
            stateflags: row["StateFlags"],
            packageflags: row["PackageFlags"],
            multiplicity: row["Multiplicity"],
            styleex: row["StyleEx"],
            actionflags: row["ActionFlags"],
            eventflags: row["EventFlags"],
          )
        end

        # Check if object is abstract
        # @return [Boolean]
        def abstract?
          abstract == "1"
        end

        # Check if object is a UML Class
        # @return [Boolean]
        def uml_class?
          object_type == "Class"
        end

        # Check if object is an Interface
        # @return [Boolean]
        def interface?
          object_type == "Interface"
        end

        # Check if object is a Component
        # @return [Boolean]
        def component?
          object_type == "Component"
        end

        # Check if object is a Package
        # @return [Boolean]
        def package?
          object_type == "Package"
        end

        # Check if object is an Enumeration
        # @return [Boolean]
        def enumeration?
          object_type == "Enumeration"
        end

        # Check if object is a DataType
        # @return [Boolean]
        def data_type?
          object_type == "DataType"
        end

        # Check if object is an Instance (UML Object)
        # @return [Boolean]
        def instance?
          object_type == "Object"
        end

        # Check if object is root
        # @return [Boolean]
        def root?
          isroot == 1
        end

        # Check if object is leaf
        # @return [Boolean]
        def leaf?
          isleaf == 1
        end
      end
    end
  end
end
