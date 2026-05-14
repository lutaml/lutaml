# frozen_string_literal: true

module Lutaml
  module Qea
    module Infrastructure
      autoload :DatabaseConnection,
               "lutaml/qea/infrastructure/database_connection"
      autoload :SchemaReader, "lutaml/qea/infrastructure/schema_reader"
      autoload :TableReader, "lutaml/qea/infrastructure/table_reader"
    end
  end
end
