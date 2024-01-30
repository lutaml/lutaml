require "lutaml/xml/parsers/xml"

require "lutaml/xml/mapper"
require "lutaml/xml/lutaml_path/document_wrapper"

require "shale"
require "shale/adapter/nokogiri"

Shale.xml_adapter = Shale::Adapter::Nokogiri
