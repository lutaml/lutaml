# frozen_string_literal: true

require "stringio"

module Expressir
  module Express
    # Declaration listing and SMRL index writers — ports of eeng
    # plugins/p11/wo-list.lisp and wo-smrl-xml.lisp (parity-ee stage 09).
    #
    # Two encodings share the same schema walk and declaration ordering
    # (TYPE, ENTITY, SUBTYPE_CONSTRAINT, FUNCTION, RULE, PROCEDURE —
    # each sorted by name):
    #   :list     — human-readable SCHEMA.name; inventory
    #   :smrl_xml — <concatenated_express_file_content_list> index
    class Listing
      DECL_ORDER = %i[types entities subtype_constraints functions rules procedures].freeze
      DECL_LABEL = {
        types: "TYPE",
        entities: "ENTITY",
        subtype_constraints: "SUBTYPE_CONSTRAINT",
        functions: "FUNCTION",
        rules: "RULE",
        procedures: "PROCEDURE",
      }.freeze
      XML_TAG = {
        types: "type",
        entities: "entity",
        subtype_constraints: "subtype_constraint",
        functions: "function",
        rules: "rule",
        procedures: "procedure",
      }.freeze

      def self.list(schemas, io = nil)
        new(Array(schemas)).write(:list, io)
      end

      def self.smrl_xml(schemas, io = nil, source: nil)
        new(Array(schemas)).write(:smrl_xml, io, source: source)
      end

      def initialize(schemas)
        @schemas = schemas.compact.sort_by { |s| s.id.to_s.downcase }
      end

      def write(encoding, io = nil, source: nil)
        owned = io.nil?
        io ||= +""
        case encoding
        when :list then write_list(io)
        when :smrl_xml then write_smrl_xml(io, source: source)
        else
          raise ArgumentError, "unknown listing encoding #{encoding.inspect}"
        end
        owned ? io : nil
      end

      private

      def write_list(io)
        @schemas.each_with_index do |schema, i|
          io << "\n" if i.positive?
          write_schema_list(schema, io)
        end
      end

      def write_schema_list(schema, io)
        version = schema.version ? " #{schema.version}" : ""
        io << "SCHEMA #{schema.id.downcase}#{version};\n\n"
        counts = decl_counts(schema)
        DECL_ORDER.each do |key|
          io << format("(* %-20s %4d *)\n", DECL_LABEL[key], counts[key])
        end
        ifaces = Array(schema.interfaces)
        if ifaces.any?
          io << "\n"
          ifaces.each do |iface|
            kind = iface.kind == Model::Declarations::Interface::REFERENCE ? "REFERENCE FROM" : "USE FROM"
            target = iface_name(iface)
            suffix = Array(iface.items).any? ? "(...)" : ""
            io << "    #{kind} #{target}#{suffix};\n"
          end
        end
        constants = Array(schema.constants).sort_by { |c| c.id.to_s.downcase }
        if constants.any?
          io << "\n"
          constants.each { |c| io << "  CONSTANT #{c.id.downcase};\n" }
        end
        decls = ordered_decls(schema)
        if decls.any?
          io << "\n"
          decls.each do |key, name|
            io << "  #{DECL_LABEL[key]} #{schema.id}.#{name.downcase};\n"
          end
        end
      end

      def write_smrl_xml(io, source: nil)
        io << "<!-- Written by Expressir -->\n"
        io << "<!--    #{Expressir::VERSION} -->\n"
        io << "<!-- File: #{source} -->\n" if source
        io << "<concatenated_express_file_content_list>\n\n"
        names = @schemas.map { |s| schema_name_string(s.id) }
        io << "<!-- #{@schemas.size} Schema#{'ta' unless @schemas.size == 1}:\n"
        io << "   #{names.join(', ')}\n"
        io << "-->\n"
        @schemas.each do |schema|
          io << "\n\n"
          write_schema_xml(schema, io)
        end
        io << "\n</concatenated_express_file_content_list>\n"
      end

      def write_schema_xml(schema, io)
        io << "<schema>#{schema_name_string(schema.id)}</schema>\n"
        if schema.version
          io << "   <schema_version>#{schema.version}</schema_version>\n"
        end
        counts = decl_counts(schema)
        DECL_ORDER.each do |key|
          io << format("  <!-- %-20s %4d -->\n", DECL_LABEL[key], counts[key])
        end
        Array(schema.interfaces).each do |iface|
          tag = iface.kind == Model::Declarations::Interface::REFERENCE ? "reference-from" : "use-from"
          target = iface_name(iface)
          suffix = Array(iface.items).any? ? "(...)" : ""
          io << "    <#{tag}>#{target}#{suffix}</#{tag}>\n"
        end
        Array(schema.constants).sort_by { |c| c.id.to_s.downcase }.each do |c|
          io << "  <constant>#{c.id.downcase}</constant>\n"
        end
        ordered_decls(schema).each do |key, name|
          tag = XML_TAG[key] || key.to_s
          cased = if key == :entities && arm_mode?(schema)
                    name.split("_").map(&:capitalize).join("_")
                  else
                    name.downcase
                  end
          io << "  <#{tag}>#{schema.id}.#{cased}</#{tag}>\n"
        end
      end

      def decl_counts(schema)
        DECL_ORDER.to_h { |k| [k, Array(schema.public_send(k)).size] }
      end

      def ordered_decls(schema)
        DECL_ORDER.flat_map do |key|
          Array(schema.public_send(key))
            .sort_by { |d| d.id.to_s.downcase }
            .map { |d| [key, d.id] }
        end
      end

      def iface_name(iface)
        name = iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
        schema_name_string(name)
      end

      # eeng schema-name-string: arm/mim/arm_lf/mim_lf tails stay lowercase;
      # everything else downcased.
      def schema_name_string(name)
        return "" unless name

        name.to_s.downcase
      end

      def arm_mode?(schema)
        id = schema.id.to_s.downcase
        id.end_with?("arm", "arm_lf")
      end
    end
  end
end
