# frozen_string_literal: true

module Lutaml
  module Qea
    module Validation
      autoload :ValidationMessage, "lutaml/qea/validation/validation_message"
      autoload :ValidationResult, "lutaml/qea/validation/validation_result"
      autoload :BaseValidator, "lutaml/qea/validation/base_validator"
      autoload :ValidatorRegistry, "lutaml/qea/validation/validator_registry"
      autoload :AssociationValidator,
               "lutaml/qea/validation/association_validator"
      autoload :AttributeValidator, "lutaml/qea/validation/attribute_validator"
      autoload :ClassValidator, "lutaml/qea/validation/class_validator"
      autoload :DiagramValidator, "lutaml/qea/validation/diagram_validator"
      autoload :OperationValidator, "lutaml/qea/validation/operation_validator"
      autoload :PackageValidator, "lutaml/qea/validation/package_validator"
      autoload :ReferentialIntegrityValidator,
               "lutaml/qea/validation/database/referential_integrity_validator"
      autoload :OrphanValidator,
               "lutaml/qea/validation/database/orphan_validator"
      autoload :CircularReferenceValidator,
               "lutaml/qea/validation/database/circular_reference_validator"
      autoload :Database, "lutaml/qea/validation/database"
      autoload :ValidationEngine, "lutaml/qea/validation/validation_engine"
    end
  end
end
