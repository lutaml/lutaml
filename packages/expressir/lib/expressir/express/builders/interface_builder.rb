# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds interface specification nodes (use/reference clauses).
      class InterfaceBuilder
        def build_interface_specification(ast_data)
          ast_data = ast_data[:interface_specification] if ast_data[:interface_specification]
          if ast_data[:reference_clause]
            Builder.build({ reference_clause: ast_data[:reference_clause] })
          elsif ast_data[:use_clause]
            Builder.build({ use_clause: ast_data[:use_clause] })
          end
        end

        def build_use_clause(ast_data)
          schema_ref_data = ast_data[:schema_ref]
          schema = if schema_ref_data
                     Builder.build({ schema_ref: schema_ref_data })
                   end

          list_data = ast_data[:list_of_named_type_or_rename]
          items = build_items(list_data, :named_type_or_rename)

          Expressir::Model::Declarations::Interface.new(
            kind: Expressir::Model::Declarations::Interface::USE,
            schema: schema,
            items: items.compact,
          )
        end

        def build_reference_clause(ast_data)
          schema_ref_data = ast_data[:schema_ref]
          schema = if schema_ref_data
                     Builder.build({ schema_ref: schema_ref_data })
                   end

          list_data = ast_data[:list_of_resource_or_rename]
          items = build_items(list_data, :resource_or_rename)

          Expressir::Model::Declarations::Interface.new(
            kind: Expressir::Model::Declarations::Interface::REFERENCE,
            schema: schema,
            items: items.compact,
          )
        end

        def build_named_type_or_rename(ast_data)
          named_types_data = ast_data[:named_types]
          ref = if named_types_data.is_a?(Hash)
                  if named_types_data[:entity_ref]
                    Builder.build({ entity_ref: named_types_data[:entity_ref] })
                  elsif named_types_data[:type_ref]
                    Builder.build({ type_ref: named_types_data[:type_ref] })
                  end
                end

          id = nil
          if ast_data[:entity_id].is_a?(Hash)
            id = Builder.build({ entity_id: ast_data[:entity_id] })
          elsif ast_data[:type_id].is_a?(Hash)
            id = Builder.build({ type_id: ast_data[:type_id] })
          end

          Expressir::Model::Declarations::InterfaceItem.new(ref: ref, id: id)
        end

        def build_resource_or_rename(ast_data)
          ref_data = ast_data[:resource_ref]
          ref = if ref_data.is_a?(Hash)
                  if ref_data[:constant_ref]
                    Builder.build({ constant_ref: ref_data[:constant_ref] })
                  elsif ref_data[:entity_ref]
                    Builder.build({ entity_ref: ref_data[:entity_ref] })
                  elsif ref_data[:function_ref]
                    Builder.build({ function_ref: ref_data[:function_ref] })
                  elsif ref_data[:procedure_ref]
                    Builder.build({ procedure_ref: ref_data[:procedure_ref] })
                  elsif ref_data[:type_ref]
                    Builder.build({ type_ref: ref_data[:type_ref] })
                  end
                end

          id_data = ast_data[:rename_id]
          id = if id_data.is_a?(Hash)
                 if id_data[:constant_id]
                   Builder.build({ constant_id: id_data[:constant_id] })
                 elsif id_data[:entity_id]
                   Builder.build({ entity_id: id_data[:entity_id] })
                 elsif id_data[:function_id]
                   Builder.build({ function_id: id_data[:function_id] })
                 elsif id_data[:procedure_id]
                   Builder.build({ procedure_id: id_data[:procedure_id] })
                 elsif id_data[:type_id]
                   Builder.build({ type_id: id_data[:type_id] })
                 end
               end

          Expressir::Model::Declarations::InterfaceItem.new(ref: ref, id: id)
        end

        def build_resource_ref(ast_data)
          if ast_data[:constant_ref]
            Builder.build({ constant_ref: ast_data[:constant_ref] })
          elsif ast_data[:entity_ref]
            Builder.build({ entity_ref: ast_data[:entity_ref] })
          elsif ast_data[:function_ref]
            Builder.build({ function_ref: ast_data[:function_ref] })
          elsif ast_data[:procedure_ref]
            Builder.build({ procedure_ref: ast_data[:procedure_ref] })
          elsif ast_data[:type_ref]
            Builder.build({ type_ref: ast_data[:type_ref] })
          end
        end

        def build_rename_id(ast_data)
          if ast_data[:constant_id]
            Builder.build({ constant_id: ast_data[:constant_id] })
          elsif ast_data[:entity_id]
            Builder.build({ entity_id: ast_data[:entity_id] })
          elsif ast_data[:function_id]
            Builder.build({ function_id: ast_data[:function_id] })
          elsif ast_data[:procedure_id]
            Builder.build({ procedure_id: ast_data[:procedure_id] })
          elsif ast_data[:type_id]
            Builder.build({ type_id: ast_data[:type_id] })
          end
        end

        private

        def build_items(list_data, item_key)
          if list_data.is_a?(Hash)
            items_data = list_data[item_key]
            items_data ? [Builder.build({ item_key => items_data })] : []
          elsif list_data.is_a?(Array)
            list_data.filter_map do |item|
              next unless item.is_a?(Hash)

              items_data = item[item_key]
              Builder.build({ item_key => items_data }) if items_data
            end
          else
            []
          end
        end
      end
    end
  end
end
