module Expressir
  module Express
    module Formatters
      module DeclarationsFormatter
        def self.included(base)
          base.register_formatter Model::Declarations::Attribute,
                                  :format_declarations_attribute
          base.register_formatter Model::Declarations::Constant,
                                  :format_declarations_constant
          base.register_formatter Model::Declarations::Entity,
                                  :format_declarations_entity
          base.register_formatter Model::Declarations::Function,
                                  :format_declarations_function
          base.register_formatter Model::Declarations::Interface,
                                  :format_declarations_interface
          base.register_formatter Model::Declarations::InterfaceItem,
                                  :format_declarations_interface_item
          base.register_formatter Model::Declarations::Parameter,
                                  :format_declarations_parameter
          base.register_formatter Model::Declarations::Procedure,
                                  :format_declarations_procedure
          base.register_formatter Model::Declarations::Rule,
                                  :format_declarations_rule
          base.register_formatter Model::Declarations::Schema,
                                  :format_declarations_schema
          base.register_formatter Model::Declarations::SchemaVersion,
                                  :format_declarations_schema_version
          base.register_formatter Model::Declarations::SubtypeConstraint,
                                  :format_declarations_subtype_constraint
          base.register_formatter Model::Declarations::Type,
                                  :format_declarations_type
          base.register_formatter Model::Declarations::UniqueRule,
                                  :format_declarations_unique_rule
          base.register_formatter Model::Declarations::Variable,
                                  :format_declarations_variable
          base.register_formatter Model::Declarations::WhereRule,
                                  :format_declarations_where_rule
          base.register_formatter Model::Declarations::InformalPropositionRule,
                                  :format_declarations_informal_proposition_rule
          base.register_formatter Model::Declarations::DerivedAttribute,
                                  :format_declarations_attribute
          base.register_formatter Model::Declarations::InverseAttribute,
                                  :format_declarations_attribute
        end

        def format_declarations_attribute(node)
          [
            *if node.supertype_attribute
               [
                 format(node.supertype_attribute),
                 " ",
               ].join
             end,
            *if node.supertype_attribute && node.id != node.supertype_attribute.attribute.id
               [
                 "RENAMED",
                 " ",
                 node.id,
                 " ",
               ].join
             end,
            *if node.id && !node.supertype_attribute
               [
                 node.id,
                 " ",
               ].join
             end,
            ":",
            *if node.optional
               [
                 " ",
                 "OPTIONAL",
               ].join
             end,
            " ",
            format(node.type),
            *if node.kind == Model::Declarations::Attribute::DERIVED
               [
                 " ",
                 ":=",
                 " ",
                 format(node.expression),
               ].join
             elsif node.kind == Model::Declarations::Attribute::INVERSE
               [
                 " ",
                 "FOR",
                 " ",
                 format(node.expression),
               ].join
             end,
            ";",
            format_inline_tail_remark(node),
          ].join
        end

        def format_declarations_constant(node)
          [
            node.id,
            " ",
            ":",
            " ",
            format(node.type),
            " ",
            ":=",
            " ",
            format(node.expression),
            ";",
          ].join
        end

        def format_declarations_entity(node)
          attrs = entity_attribute_items(node)
          explicit_attributes = attrs.select do |x|
            x.kind == Model::Declarations::Attribute::EXPLICIT
          end
          derived_attributes = attrs.select do |x|
            x.kind == Model::Declarations::Attribute::DERIVED
          end
          inverse_attributes = attrs.select do |x|
            x.kind == Model::Declarations::Attribute::INVERSE
          end

          indent_const = self.class.const_get(:INDENT)
          # Only show preamble remarks if entity has explicit attributes
          preamble = if explicit_attributes&.length&.positive?
                       format_preamble_remarks(node, indent(indent_const))
                     end

          [
            [
              "ENTITY",
              " ",
              node.id,
              *if node.abstract && !node.supertype_expression
                 [
                   "\n",
                   indent([
                     "ABSTRACT",
                     " ",
                     "SUPERTYPE",
                   ].join),
                 ].join
               end,
              *if node.abstract && node.supertype_expression
                 [
                   "\n",
                   indent([
                     "ABSTRACT",
                     " ",
                     "SUPERTYPE",
                     " ",
                     "OF",
                     " ",
                     "(",
                     format(node.supertype_expression),
                     ")",
                   ].join),
                 ].join
               end,
              *if !node.abstract && node.supertype_expression
                 [
                   "\n",
                   indent([
                     "SUPERTYPE",
                     " ",
                     "OF",
                     " ",
                     "(",
                     format(node.supertype_expression),
                     ")",
                   ].join),
                 ].join
               end,
              *if node.subtype_of&.length&.positive?
                 [
                   "\n",
                   indent([
                     "SUBTYPE",
                     " ",
                     "OF",
                     " ",
                     "(",
                     node.subtype_of.map { |x| format(x) }.join(", "),
                     ")",
                   ].join),
                 ].join
               end,
              ";",
            ].join,
            *if preamble && !preamble.empty?
               preamble.rstrip
             end,
            *if explicit_attributes&.length&.positive?
               indent(explicit_attributes.map { |x| format(x) }.join("\n"))
             end,
            *if derived_attributes&.length&.positive?
               [
                 "DERIVE",
                 indent(derived_attributes.map { |x| format(x) }.join("\n")),
               ]
             end,
            *if inverse_attributes&.length&.positive?
               [
                 "INVERSE",
                 indent(inverse_attributes.map { |x| format(x) }.join("\n")),
               ]
             end,
            *if node.unique_rules&.length&.positive?
               [
                 "UNIQUE",
                 indent(node.unique_rules.map { |x| format(x) }.join("\n")),
               ]
             end,
            *if node.where_rules&.length&.positive?
               [
                 "WHERE",
                 indent(node.where_rules.map { |x| format(x) }.join("\n")),
               ]
             end,
            [
              "END_ENTITY",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        # Entity#attributes is the Ruby-parse layout (every attribute kind
        # in one list). The core path parks derived/inverse in their own
        # collections instead. Both may also arrive as Array-of-Array when
        # a builder nested list productions. Normalize to a flat list of
        # Attribute-like nodes before selecting on `kind`.
        def entity_attribute_items(node)
          items = Array(node.attributes)
          items += Array(node.derived_attributes) if node.respond_to?(:derived_attributes)
          items += Array(node.inverse_attributes) if node.respond_to?(:inverse_attributes)
          items.flatten.compact.uniq(&:object_id)
        end

        def format_declarations_function(node)
          indent_char = self.class.const_get(:INDENT_CHAR)
          [
            [
              "FUNCTION",
              " ",
              node.id,
              # nil parameters = the source had no parentheses;
              # [] = an explicit `f()` — the parens are written back
              *if node.parameters
                 parameter_indent = indent_char * "FUNCTION #{node.id}(".length
                 [
                   "(",
                   node.parameters.map do |x|
                     format(x)
                   end.join(";\n#{parameter_indent}"),
                   ")",
                 ].join
               end,
              " ",
              ":",
              " ",
              format(node.return_type),
              ";",
            ].join,
            *if node.types&.length&.positive?
               indent(node.types.map { |x| format(x) }.join("\n"))
             end,
            *if node.entities&.length&.positive?
               indent(node.entities.map { |x| format(x) }.join("\n"))
             end,
            *if node.subtype_constraints&.length&.positive?
               indent(node.subtype_constraints.map { |x| format(x) }.join("\n"))
             end,
            *if node.functions&.length&.positive?
               indent(node.functions.map { |x| format(x) }.join("\n"))
             end,
            *if node.procedures&.length&.positive?
               indent(node.procedures.map { |x| format(x) }.join("\n"))
             end,
            *if node.constants&.length&.positive?
               indent([
                 "CONSTANT",
                 indent(node.constants.map { |x| format(x) }.join("\n")),
                 [
                   "END_CONSTANT",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if node.variables&.length&.positive?
               indent([
                 "LOCAL",
                 indent(node.variables.map { |x| format(x) }.join("\n")),
                 [
                   "END_LOCAL",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if node.statements&.length&.positive?
               indent(node.statements.map { |x| format(x) }.join("\n"))
             end,
            *format_trailing_region_remarks(node, :statements).map { |x| indent(x) },
            [
              "END_FUNCTION",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        def format_declarations_interface(node)
          indent_char = self.class.const_get(:INDENT_CHAR)
          [
            case node.kind
            when Model::Declarations::Interface::USE then "USE"
            when Model::Declarations::Interface::REFERENCE then "REFERENCE"
            end,
            " ",
            "FROM",
            " ",
            format(node.schema),
            *if node.items&.length&.positive?
               item_indent = indent_char * "(".length
               [
                 "\n",
                 indent([
                   "(",
                   node.items.map { |x| format(x) }.join(",\n#{item_indent}"),
                   ")",
                 ].join),
               ].join
             end,
            ";",
          ].join
        end

        def format_declarations_interface_item(node)
          [
            format(node.ref),
            *if node.id
               [
                 " ",
                 "AS",
                 " ",
                 node.id,
               ]
             end,
          ].join
        end

        def format_declarations_parameter(node)
          [
            *if node.var
               [
                 "VAR",
                 " ",
               ].join
             end,
            node.id,
            " ",
            ":",
            " ",
            format(node.type),
          ].join
        end

        def format_declarations_procedure(node)
          indent_char = self.class.const_get(:INDENT_CHAR)
          [
            [
              "PROCEDURE",
              " ",
              node.id,
              # see format_declarations_function: nil = no parens,
              # [] = explicit `p()`
              *if node.parameters
                 parameter_indent = indent_char * "PROCEDURE #{node.id}(".length
                 [
                   "(",
                   node.parameters.map do |x|
                     format(x)
                   end.join(";\n#{parameter_indent}"),
                   ")",
                 ].join
               end,
              ";",
            ].join,
            *if node.types&.length&.positive?
               indent(node.types.map { |x| format(x) }.join("\n"))
             end,
            *if node.entities&.length&.positive?
               indent(node.entities.map { |x| format(x) }.join("\n"))
             end,
            *if node.subtype_constraints&.length&.positive?
               indent(node.subtype_constraints.map { |x| format(x) }.join("\n"))
             end,
            *if node.functions&.length&.positive?
               indent(node.functions.map { |x| format(x) }.join("\n"))
             end,
            *if node.procedures&.length&.positive?
               indent(node.procedures.map { |x| format(x) }.join("\n"))
             end,
            *if node.constants&.length&.positive?
               indent([
                 "CONSTANT",
                 indent(node.constants.map { |x| format(x) }.join("\n")),
                 [
                   "END_CONSTANT",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if node.variables&.length&.positive?
               indent([
                 "LOCAL",
                 indent(node.variables.map { |x| format(x) }.join("\n")),
                 [
                   "END_LOCAL",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if node.statements&.length&.positive?
               indent(node.statements.map { |x| format(x) }.join("\n"))
             end,
            *format_trailing_region_remarks(node, :statements).map { |x| indent(x) },
            [
              "END_PROCEDURE",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        # True when the statement holds a remark that only it can render.
        # Under no_remarks nothing is emitted anyway, so the statement stays
        # filtered and remark-free output is byte-identical to before.
        def carries_placed_remark?(statement)
          return false if @no_remarks

          Array(statement.untagged_remarks).any?(&:placement)
        end

        def format_declarations_rule(node)
          # Filter out statements that only exist to hold remarks in
          # rules (ALIAS/REPEAT with only Null sub-statements, or Null
          # statements). A query assignment is executable rule code
          # (#555) — it is never dropped.
          formatted_statements = []
          if node.statements&.length&.positive?
            formatted_statements = node.statements.reject do |stmt|
              # A statement holding a placed remark is the only thing that can
              # render it, so filtering it would silently drop the comment —
              # and PrettyFormatter, which does not filter, would then produce
              # different content from this formatter.
              if carries_placed_remark?(stmt)
                false
              elsif stmt.is_a?(Model::Statements::Alias) || stmt.is_a?(Model::Statements::Repeat)
                stmt.statements&.all?(Model::Statements::Null)
              elsif stmt.is_a?(Model::Statements::Null)
                true
              else
                false
              end
            end
          end

          [
            [
              "RULE",
              " ",
              node.id,
              " ",
              "FOR",
              " ",
              "(",
              Array(node.applies_to).map { |x| format(x) }.join(", "),
              ")",
              ";",
            ].join,
            *if node.types&.length&.positive?
               indent(node.types.map { |x| format(x) }.join("\n"))
             end,
            *if node.entities&.length&.positive?
               indent(node.entities.map { |x| format(x) }.join("\n"))
             end,
            *if node.subtype_constraints&.length&.positive?
               indent(node.subtype_constraints.map { |x| format(x) }.join("\n"))
             end,
            *if node.functions&.length&.positive?
               indent(node.functions.map { |x| format(x) }.join("\n"))
             end,
            *if node.procedures&.length&.positive?
               indent(node.procedures.map { |x| format(x) }.join("\n"))
             end,
            *if node.constants&.length&.positive?
               indent([
                 "CONSTANT",
                 indent(node.constants.map { |x| format(x) }.join("\n")),
                 [
                   "END_CONSTANT",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if node.variables&.length&.positive?
               indent([
                 "LOCAL",
                 indent(node.variables.map { |x| format(x) }.join("\n")),
                 [
                   "END_LOCAL",
                   ";",
                 ].join,
               ].join("\n"))
             end,
            *if formatted_statements.length.positive?
               indent(formatted_statements.map { |x| format(x) }.join("\n"))
             end,
            # A RULE's executable body ends at WHERE, so its trailing
            # remarks belong above that keyword, not after the where rules.
            *format_trailing_region_remarks(node, :statements).map { |x| indent(x) },
            *if node.where_rules&.length&.positive?
               [
                 "WHERE",
                 indent(node.where_rules.map { |x| format(x) }.join("\n")),
               ]
             end,
            # A comment after the last where rule closes the WHERE section.
            *format_trailing_region_remarks(node, :where_rules).map { |x| indent(x) },
            [
              "END_RULE",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        def format_declarations_schema_head(node)
          [
            [
              "SCHEMA",
              " ",
              node.id,
              *if node.version
                 [
                   " ",
                   format(node.version),
                 ].join
               end,
              ";",
            ].join,
            *if node.interfaces&.length&.positive?
               [
                 "",
                 node.interfaces.map { |x| format(x) }.join("\n\n"),
               ]
             end,
          ].join("\n")
        end

        def format_declarations_schema(node)
          indent_const = self.class.const_get(:INDENT)
          preamble = format_preamble_remarks(node, indent(indent_const))

          schema_declarations = [
            *if node.constants&.length&.positive?
               [
                 "CONSTANT",
                 indent(node.constants.map { |x| format(x) }.join("\n")),
                 [
                   "END_CONSTANT",
                   ";",
                 ].join,
               ].join("\n")
             end,
            *if node.types&.length&.positive?
               node.types.map { |x| format(x) }
             end,
            *if node.entities&.length&.positive?
               node.entities.map { |x| format(x) }
             end,
            *if node.subtype_constraints&.length&.positive?
               node.subtype_constraints.map { |x| format(x) }
             end,
            *if node.functions&.length&.positive?
               node.functions.map { |x| format(x) }
             end,
            *if node.rules&.length&.positive?
               node.rules.map { |x| format(x) }
             end,
            *if node.procedures&.length&.positive?
               node.procedures.map { |x| format(x) }
             end,
          ]

          [
            format_declarations_schema_head(node),
            *if preamble && !preamble.empty?
               [
                 "",
                 preamble.rstrip,
                 "",
               ]
             end,
            *if schema_declarations&.length&.positive?
               [
                 "",
                 schema_declarations.join("\n\n"),
                 "",
               ]
             end,
            [
              "END_SCHEMA",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        def format_declarations_schema_version(node)
          [
            "'",
            node.value,
            "'",
          ].join
        end

        def format_declarations_subtype_constraint(node)
          [
            [
              "SUBTYPE_CONSTRAINT",
              " ",
              node.id,
              " ",
              "FOR",
              " ",
              format(node.applies_to),
              ";",
            ].join,
            # ISO 10303-11:2004 syntax 314 subtype_constraint_body =
            # [ abstract_supertype ] ... with syntax 165
            # abstract_supertype = ABSTRACT SUPERTYPE ';' — the
            # constraint body carries the SUPERTYPE keyword (unlike
            # the entity header's abstract_supertype_constraint).
            *if node.abstract
               indent([
                 "ABSTRACT",
                 " ",
                 "SUPERTYPE",
                 ";",
               ].join)
             end,
            *if node.total_over&.length&.positive?
               indent([
                 "TOTAL_OVER",
                 "(",
                 node.total_over.map { |x| format(x) }.join(", "),
                 ")",
                 ";",
               ].join)
             end,
            *if node.supertype_expression
               indent([
                 format(node.supertype_expression),
                 ";",
               ].join)
             end,
            [
              "END_SUBTYPE_CONSTRAINT",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        def format_declarations_type(node)
          [
            [
              "TYPE",
              " ",
              node.id,
              " ",
              "=",
              " ",
              format(node.underlying_type),
              ";",
            ].join,
            *if node.where_rules&.length&.positive?
               [
                 "WHERE",
                 indent(node.where_rules.map { |x| format(x) }.join("\n")),
               ]
             end,
            [
              "END_TYPE",
              ";",
              format_end_scope_remark(node),
            ].join,
          ].join("\n")
        end

        def format_declarations_unique_rule(node)
          [
            *if node.id
               [
                 node.id,
                 ":",
                 " ",
               ].join
             end,
            Array(node.attributes).map { |x| format(x) }.join(", "),
            ";",
          ].join
        end

        def format_declarations_variable(node)
          [
            node.id,
            " ",
            ":",
            " ",
            format(node.type),
            *if node.expression
               [
                 " ",
                 ":=",
                 " ",
                 format(node.expression),
               ].join
             end,
            ";",
          ].join
        end

        def format_declarations_where_rule(node)
          [
            *if node.id
               [
                 node.id,
                 ":",
                 " ",
               ].join
             end,
            format(node.expression),
            ";",
          ].join
        end

        def format_declarations_informal_proposition_rule(node)
          [
            *if node.id
               [
                 node.id,
                 ":",
                 " ",
               ].join
             end,
          ].join
        end
      end
    end
  end
end
