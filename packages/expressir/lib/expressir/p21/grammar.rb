# frozen_string_literal: true

require "parsanol"

module Expressir
  module P21
    # ISO 10303-21 exchange-structure grammar (TODO.eengine/06 step 1).
    # Parses the HEADER section and the DATA section's instance list
    # into a capture tree; {Expressir::P21::PopulationBuilder} turns
    # the tree into a {Expressir::P21::Population}.
    #
    # Reference: ISO 10303-21 exchange structure grammar
    # (`~/src/mn/iso-10303-detached-docs/sources/iso-10303-21*/`);
    # scope ladder in TODO.eengine/06 — the supported subset is the
    # header FILE_* entities plus simple/complex data instances with
    # lists, typed parameters, references, enumerations, binaries,
    # strings, unset ($) and derived (*).
    class Grammar < Parsanol::Parser
      root(:exchange_structure)

      rule(:comment) { str("/*") >> (str("*/").absent? >> any).repeat >> str("*/") }
      rule(:ws?) { (match[" \t\r\n"] | comment).repeat }
      rule(:ws1) { (match[" \t\r\n"] | comment).repeat(1) }
      rule(:keyword) { match["!"].maybe >> match["A-Za-z0-9_"].repeat(1) }
      rule(:entity_instance_name) { str("#") >> match["0-9"].repeat(1) }
      rule(:constant_reference) do
        str("#") >> match["A-Za-z_"] >> match["A-Za-z0-9_"].repeat
      end
      rule(:external_anchor) do
        str("<") >> (str(">").absent? >> any).repeat >> str(">")
      end

      rule(:string_literal) do
        # ISO 10303-21: doubled quotes are escaped quotes
        str("'") >> ((str("'").absent? >> any) | str("''")).repeat >> str("'")
      end
      rule(:binary_literal) { str('"') >> match["0-9A-Fa-f"].repeat >> str('"') }
      rule(:enumeration) { str(".") >> match["A-Za-z0-9_"].repeat(1) >> str(".") }
      rule(:unset) { str("$") }
      rule(:derived) { str("*") }

      rule(:parameter_list) do
        str("(") >> ws? >>
          (parameter.as(:parameter) >>
            (str(",") >> ws? >> parameter.as(:parameter)).repeat).maybe >>
          str(")") >> ws?
      end

      rule(:typed_parameter) do
        keyword.as(:keyword) >> ws? >> parameter_list.as(:parameter_list)
      end
      rule(:list_parameter) { parameter_list }

      rule(:number_literal) do
        match["+-"].maybe >> match["0-9"].repeat(1) >>
          (str(".") >> match["0-9"].repeat(1)).maybe >>
          (match["Ee"] >> match["+-"].maybe >> match["0-9"].repeat(1)).maybe
      end

      rule(:parameter) do
        typed_parameter.as(:typed_parameter) |
          list_parameter.as(:parameter_list) |
          entity_instance_name.as(:entity_instance_name) |
          constant_reference.as(:constant_reference) |
          external_anchor.as(:external_anchor) |
          number_literal.as(:number_literal) |
          enumeration.as(:enumeration) |
          binary_literal.as(:binary_literal) |
          string_literal.as(:string_literal) |
          unset.as(:unset) | derived.as(:derived)
      end

      rule(:simple_record) do
        keyword.as(:keyword) >> ws? >> parameter_list.as(:parameter_list)
      end

      rule(:subsuper_record) do
        str("(") >> ws? >> simple_record.as(:simple_record).repeat(1) >>
          str(")") >> ws?
      end

      rule(:simple_entity_instance) do
        (entity_instance_name.as(:entity_instance_name) >> ws? >>
          str("=") >> ws? >> simple_record.as(:simple_record) >>
          str(";") >> ws?).as(:simple_entity_instance)
      end
      rule(:complex_entity_instance) do
        (entity_instance_name.as(:entity_instance_name) >> ws? >>
          str("=") >> ws? >> subsuper_record.as(:subsuper_record) >>
          str(";") >> ws?).as(:complex_entity_instance)
      end
      rule(:external_reference_instance) do
        (entity_instance_name.as(:entity_instance_name) >> ws? >>
          str("=") >> ws? >> external_anchor.as(:external_anchor) >>
          str(";") >> ws?).as(:external_reference_instance)
      end
      rule(:entity_instance) do
        complex_entity_instance | simple_entity_instance |
          external_reference_instance
      end

      rule(:header_entity) do
        simple_record.as(:simple_record) >> str(";") >> ws?
      end
      # ISO 10303-21:2016 clause 14: two signature lines open the
      # header of a signed exchange structure.
      rule(:signature_lines) { (str("..") >> ws?).repeat }
      rule(:header_section) do
        str("HEADER;") >> ws? >> signature_lines >>
          header_entity.repeat(1).as(:header_entity) >>
          str("ENDSEC;") >> ws?
      end
      rule(:data_section) do
        (str("DATA") >> ws? >>
          parameter_list.as(:section_tag).maybe >> str(";") >> ws? >>
          entity_instance.repeat.as(:instance_list) >>
          str("ENDSEC;") >> ws?).as(:data_section)
      end
      # ISO 10303-21:2016 clause 9: the anchor section binds labels to
      # local instances (a promissory anchor binds the unset value).
      rule(:anchor_entry) do
        ((str("<") >> str(">").absent? >>
           match["A-Za-z0-9_./:#?=&%-"].repeat.as(:anchor_label) >>
           str(">") >> ws? >> str("=") >> ws? >>
           (entity_instance_name.as(:entity_instance_name) |
            unset.as(:unset))) >> str(";") >> ws?).as(:anchor_entry)
      end
      rule(:anchor_section) do
        (str("ANCHOR;") >> ws? >> anchor_entry.repeat.as(:anchor_entry) >>
          str("ENDSEC;") >> ws?).as(:anchor_section)
      end
      # ISO 10303-21:2016 clause 10: the reference section binds a
      # local instance name to an external anchor.
      rule(:reference_section) do
        (str("REFERENCE;") >> ws? >>
          entity_instance.repeat.as(:instance_list) >>
          str("ENDSEC;") >> ws?).as(:reference_section)
      end
      rule(:exchange_structure) do
        ws? >> str("ISO-10303-21;") >> ws? >>
          header_section.as(:header_section) >>
          anchor_section.maybe >>
          reference_section.maybe >>
          data_section.repeat(1).as(:data_section) >>
          str("END-ISO-10303-21;") >> ws?
      end
    end
  end
end
