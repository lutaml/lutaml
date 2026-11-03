# frozen_string_literal: true

module Expressir
  module P28
    autoload :Uos, "#{__dir__}/p28/uos"
    autoload :Xsd, "#{__dir__}/p28/xsd"
    autoload :Document, "#{__dir__}/p28/document"
    autoload :Configuration, "#{__dir__}/p28/configuration"

    # ISO 10303-28:2007 XML representation of EXPRESS-driven data.
    #
    # The common namespace shared by every -28 binding (annex C base
    # schema; clause 9 examples).
    COMMON_NS = "urn:iso:std:iso:10303:-28:ed-2:tech:XMLschema:common"

    # The default target-namespace URN for a schema registered as an
    # International Standard (clause 7, "URI for the target namespace
    # of the derived XML schema" + annex A URN form).
    module_function

    def default_target_namespace(schema_name, part: nil, version: nil)
      if part && version
        "urn:iso.org:standard:10303:part(#{part}):version(#{version}):" \
          "defaultXML:#{schema_name}"
      else
        "URN:my_company.com:iso_10303_28/#{schema_name}"
      end
    end
  end
end
