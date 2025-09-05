module Lutaml
  module Sysml
    class XmiFile
      attr_accessor :package_list, :model_list, :class_list, :activity_list,
                    :property_list, :port_list,
                    :datatype_list, :instance_list,
                    :realization_list, :abstraction_list,
                    :association_list, :connector_list,
                    :connectorend_list, :constraint_list, :block_list,
                    :constraintblock_list, :requirement_list,
                    :testcase_list, :binding_connector_list,
                    :nested_connectorend_list, :derive_requirement_list,
                    :refine_requirement_list, :trace_requirement_list,
                    :copy_requirement_list, :verify_requirement_list,
                    :satisfy_requirement_list,
                    :allocate_requirement_list, :element_hash

      def initialize # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        @package_list = []
        @model_list = []
        @class_list = []
        @activity_list = []
        @property_list = []
        @port_list = []
        @datatype_list = []
        @instance_list = []
        @realization_list = []
        @abstraction_list = []
        @association_list = []
        @connector_list = []
        @connectorend_list = []
        @constraint_list = []
        @block_list = []
        @constraintblock_list = []
        @requirement_list = []
        @testcase_list = []
        @binding_connector_list = []
        @nested_connectorend_list = []
        @derive_requirement_list = []
        @refine_requirement_list = []
        @trace_requirement_list = []
        @copy_requirement_list = []
        @verify_requirement_list = []
        @satisfy_requirement_list = []
        @allocate_requirement_list = []

        @element_hash = Hash.new
      end

      def parse(filename) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        xmifile = File.new(filename, "r")
        inxml = Nokogiri::XML(xmifile)

        xmi_elements = inxml.xpath("//xmi:XMI")
        if xmi_elements.empty?
          puts "ERROR : File contains no 'xmi:XMI' XML elements : " \
               "#{filename}, may not be XMI file."
          xmifile.close
          exit
        end

        # setup xmi namespace
        xmi_ns = inxml.root.namespace_definitions.find do |ns|
          ns.prefix == "xmi"
        end

        ## Step 1: Find UML and SysML Core Objects in XMI file and create as
        #  instance of metamodel

        inxml.xpath("//*").each do |xml_node| # rubocop:disable Metrics/BlockLength
          element_new = nil

          if xml_node.name.to_s == "packagedElement" &&
              xml_node.attribute_with_ns("type", xmi_ns.href)
                  .to_s == "uml:Package"
            element_new = Lutaml::Uml::Package.new
            package_list.push element_new
          end

          if xml_node.name.to_s == "Model"
            element_new = Lutaml::Uml::Model.new
            model_list.push element_new
            element_new.viewpoint = xml_node["viewpoint"]
            element_new.href = xml_node["href"]
          end

          if xml_node.attribute_with_ns("type", xmi_ns.href).to_s == "uml:Class"
            element_new = Lutaml::Uml::Class.new
            if !xml_node["isAbstract"].nil?
              element_new.is_abstract = xml_node["isAbstract"] == "true"
            end
            class_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Activity"
            element_new = Lutaml::Uml::Activity.new
            activity_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Property"
            element_new = Lutaml::Uml::Property.new
            property_list.push element_new
          end

          if xml_node
              .attribute_with_ns("type", xmi_ns.href)
              .to_s == "uml:InstanceSpecification"
            element_new = Lutaml::Uml::Instance.new
            instance_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:DataType"
            element_new = Lutaml::Uml::DataType.new
            datatype_list.push element_new
          end

          if xml_node.attribute_with_ns("type", xmi_ns.href).to_s == "uml:Port"
            element_new = Lutaml::Uml::Port.new
            port_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Connector"
            element_new = Lutaml::Uml::Connector.new
            connector_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:ConnectorEnd"
            element_new = Lutaml::Uml::ConnectorEnd.new
            connectorend_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Constraint"
            element_new = Lutaml::Uml::Constraint.new
            constraint_list.push element_new
          end

          if xml_node.name.to_s == "Block"
            element_new = SYSML::Block.new
            block_list.push element_new
          end

          if xml_node.name.to_s == "Template"
            element_new = SYSML::Block.new
            block_list.push element_new
          end

          if xml_node.name.to_s == "ConstraintBlock"
            element_new = SYSML::ConstraintBlock.new
            constraintblock_list.push element_new
          end

          if (
            xml_node.name.to_s.index("Requirement") ||
            xml_node.name.to_s == "designConstraint"
          ) && xml_node.name.to_s != "RequirementRelated"
            element_new = SYSML::Requirement.new
            requirement_list.push element_new
            element_new.id = xml_node.attribute_with_ns("id",
                                                        xmi_ns.href).to_s.strip
            element_new.text = xml_node["Text"]
            if xml_node.name != "Requirement"
              element_new.stereotype.push xml_node.name
            end
          end

          if xml_node.name.to_s == "TestCase"
            element_new = SYSML::TestCase.new
            testcase_list.push element_new
          end

          if xml_node.name.to_s == "BindingConnector"
            element_new = SYSML::BindingConnector.new
            binding_connector_list.push element_new
          end

          if xml_node.name.to_s == "NestedConnectorEnd"
            element_new = SYSML::NestedConnectorEnd.new
            nested_connectorend_list.push element_new
          end

          if xml_node.name.to_s == "DeriveReqt"
            element_new = SYSML::DeriveRequirement.new
            derive_requirement_list.push element_new
          end
          if xml_node.name.to_s == "refine"
            element_new = SYSML::Refine.new
            refine_requirement_list.push element_new
          end
          if xml_node.name.to_s == "trace"
            element_new = SYSML::Trace.new
            trace_requirement_list.push element_new
          end
          if xml_node.name.to_s == "Copy"
            element_new = SYSML::Copy.new
            copy_requirement_list.push element_new
          end
          if xml_node.name.to_s == "Verify"
            element_new = SYSML::Verify.new
            verify_requirement_list.push element_new
          end
          if xml_node.name.to_s == "Allocate"
            element_new = SYSML::Allocate.new
            allocate_requirement_list.push element_new
          end

          if xml_node.name.to_s == "Satisfy"
            element_new = SYSML::Satisfy.new
            satisfy_requirement_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Abstraction"
            element_new = Lutaml::Uml::Abstraction.new
            abstraction_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Realization"
            element_new = Lutaml::Uml::Realization.new
            realization_list.push element_new
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Association"
            element_new = Lutaml::Uml::Association.new
            association_list.push element_new
          end

          if !element_new.nil?
            new_xmi_id_node = xml_node.attribute_with_ns("id", xmi_ns.href)
            new_xmi_uuid_node = xml_node.attribute_with_ns("uuid", xmi_ns.href)
            new_name_node = xml_node["name"]
            new_href_node = xml_node["href"]

            if !new_xmi_id_node.nil?
              element_new.xmi_id = new_xmi_id_node.to_s
              element_hash[element_new.xmi_id] = element_new
            end

            if !new_xmi_uuid_node.nil?
              element_new.xmi_uuid = new_xmi_uuid_node.to_s
            end

            if !new_name_node.nil?
              element_new.name = xml_node["name"].strip
            end

            if !new_href_node.nil?
              element_new.href = new_href_node.to_s
              if new_xmi_id_node == nil
                element_hash[element_new.href] = element_new
              end
              if !xml_node.at("xmi:Extension/referenceExtension").nil?
                element_new.name = xml_node
                  .at("xmi:Extension/referenceExtension")["referentPath"]
              end
            end

            if !xml_node.parent.nil? &&
                !xml_node.parent.attribute_with_ns("id", xmi_ns.href).nil? &&
                !element_hash[xml_node
                    .parent.attribute_with_ns("id", xmi_ns.href).to_s].nil?

              parent = element_hash[xml_node
                .parent.attribute_with_ns("id", xmi_ns.href).to_s]
              element_new.namespace = parent
              if parent.is_a? Lutaml::Uml::Package
                parent.contents.push element_new
              end
            end
          end
        end

        inxml.xpath("//*").each do |xml_node| # rubocop:disable Metrics/BlockLength,Style/CombinableLoops
          if !xml_node.attribute_with_ns("id", xmi_ns.href).nil? &&
              !element_hash[xml_node
                  .attribute_with_ns("id", xmi_ns.href).to_s].nil?

            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
          end

          if xml_node.name.to_s == "nestedClassifier" &&
              xml_node.attribute_with_ns(
                "type", xmi_ns.href
              ).to_s == "uml:Class"
            owning_class_xmi_id = xml_node
              .parent.attribute_with_ns("id", xmi_ns.href).to_s
            owned_class_xmi_id = xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s
            owning_class = element_hash[owning_class_xmi_id]
            owned_class = element_hash[owned_class_xmi_id]
            owning_class.nested_classifier.push owned_class
          end

          if xml_node.attribute_with_ns("type", xmi_ns.href)
              .to_s == "uml:Realization"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            supplier_xmi_id = xml_node.at("supplier")["idref"]
            client_xmi_id = xml_node.at("client")["idref"]
            this_thing.supplier.push element_hash[supplier_xmi_id]
            this_thing.client.push element_hash[client_xmi_id]
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Abstraction"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            supplier_xmi_id = xml_node.at("supplier")["idref"]
            client_xmi_id = xml_node.at("client")["idref"]
            this_thing.supplier.push element_hash[supplier_xmi_id]
            this_thing.client.push element_hash[client_xmi_id]
          end

          if xml_node.name.to_s == "Block"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_class_xmi_id = xml_node["base_Class"]
            this_thing.base_class = element_hash[base_class_xmi_id]
          end

          if xml_node.name.to_s == "Template"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_class_xmi_id = xml_node["base_Class"]
            this_thing.base_class = element_hash[base_class_xmi_id]
            this_thing.base_class.stereotype.push "Template"
          end

          if xml_node.name.to_s == "ConstraintBlock"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_class_xmi_id = xml_node["base_Class"]
            this_thing.base_class = element_hash[base_class_xmi_id]
          end

          if (
            xml_node.name.to_s.index("Requirement") ||
            (xml_node.name.to_s == "designConstraint")
          ) && xml_node.name.to_s != "RequirementRelated"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_class_xmi_id = xml_node["base_Class"]
            this_thing.base_class = element_hash[base_class_xmi_id]
            this_thing.refined_by = element_hash[xml_node["RefinedBy"]]
            this_thing.derived_from = element_hash[xml_node["DerivedFrom"]]
            this_thing.traced_to = element_hash[xml_node["TracedTo"]]
          end

          if xml_node.name.to_s == "TestCase"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            this_thing.base_behavior = element_hash[xml_node["base_Behavior"]]
            this_thing.verifies = element_hash[xml_node["Verifies"]]
          end

          if xml_node.name.to_s == "BindingConnector"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_connector_xmi_id = xml_node["base_Connector"]
            this_thing.base_connector = element_hash[base_connector_xmi_id]
          end

          if xml_node.name.to_s == "NestedConnectorEnd"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_connectorend_xmi_id = xml_node["base_ConnectorEnd"]
            this_thing.base_connectorend =
              element_hash[base_connectorend_xmi_id]
            if xml_node["propertyPath"] == nil
              xml_node.xpath("./propertyPath").each do |prop_path|
                # to deal with href = '#xmi:id' i.e. local references
                href_parts = prop_path["href"].split("#")
                prop = if href_parts[0].empty?
                         element_hash[href_parts[1]]
                       else
                         element_hash[prop_path["href"]]
                       end
                this_thing.property_path.push prop
              end
            else
              this_thing.property_path
                .push element_hash[xml_node["propertyPath"]]
            end
          end

          if xml_node.name.to_s == "Satisfy"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_realization_xmi_id = xml_node["base_Realization"]
            this_thing.base_realization = element_hash[base_realization_xmi_id]
          end

          if ["DeriveReqt", "refine", "trace", "Copy", "Verify", "Allocate", # rubocop:disable Performance/CollectionLiteralInLoop
              ""].include? xml_node.name.to_s
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            base_abstraction_xmi_id = xml_node["base_Abstraction"]
            this_thing.base_abstraction = element_hash[base_abstraction_xmi_id]
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Association"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            member_end_list = xml_node.xpath("./memberEnd")
            member_end_list.each do |item|
              this_thing.member_end.push element_hash[item["idref"]]
            end
            owned_end_list = xml_node.xpath("./ownedEnd")
            owned_end_list.each do |item|
              this_thing.owned_end.push element_hash[item.attribute_with_ns(
                "id", xmi_ns.href
              ).to_s]
            end
          end

          if ["uml:Property", "uml:Port"].include?( # rubocop:disable Performance/CollectionLiteralInLoop
            xml_node.attribute_with_ns("type", xmi_ns.href).to_s,
          ) &&
              !["definingFeature", "partWithPort", "propertyPath", "role"] # rubocop:disable Performance/CollectionLiteralInLoop
                  .include?(xml_node.name.to_s)
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            if !xml_node["association"].nil?
              this_thing.association = element_hash[xml_node["association"]]
            end
            if !xml_node["aggregation"].nil?
              this_thing.aggregation = xml_node["aggregation"]
            end
            if !xml_node["visibility"].nil?
              this_thing.visibility = xml_node["visibility"]
            end

            if !xml_node.at("lowerValue").nil?

              this_thing.lowerValue = if xml_node.at("lowerValue")["value"].nil?
                                        "0"
                                      else
                                        xml_node.at("lowerValue")["value"]
                                      end
            end
            if !xml_node.at("upperValue").nil?
              this_thing.upperValue = xml_node.at("upperValue")["value"]
            end
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:Connector"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            connector_end_list = xml_node.xpath("./end")
            connector_end_list.each do |end_xml_node|
              this_thing.connector_end
                .push element_hash[end_xml_node.attribute_with_ns(
                  "id", xmi_ns.href
                ).to_s]
            end
          end

          if xml_node.attribute_with_ns("type",
                                        xmi_ns.href).to_s == "uml:ConnectorEnd"
            this_thing = element_hash[xml_node
              .attribute_with_ns("id", xmi_ns.href).to_s]
            this_thing.connector = element_hash[xml_node.parent
              .attribute_with_ns("id", xmi_ns.href).to_s]
            this_thing.role = element_hash[xml_node["role"]]
            if this_thing.role == nil
              this_thing.role = element_hash[xml_node.at("role")["href"]]
            end
            this_thing.part_with_port = element_hash[xml_node["part_with_port"]]
          end
        end
      end
    end
  end
end
