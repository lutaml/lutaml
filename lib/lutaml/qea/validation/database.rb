# frozen_string_literal: true

module Lutaml
  module Qea
    module Validation
      module Database
        autoload :CircularReferenceValidator,
                 "lutaml/qea/validation/database/circular_reference_validator"
        autoload :OrphanValidator,
                 "lutaml/qea/validation/database/orphan_validator"
        autoload :ReferentialIntegrityValidator,
                 "lutaml/qea/validation/database/referential_integrity_validator"
      end
    end
  end
end
