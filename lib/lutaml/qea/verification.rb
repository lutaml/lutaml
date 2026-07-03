# frozen_string_literal: true

module Lutaml
  module Qea
    module Verification
      autoload :DocumentNormalizer,
               "lutaml/qea/verification/document_normalizer"
      autoload :StructureMatcher, "lutaml/qea/verification/structure_matcher"
      autoload :ElementComparator, "lutaml/qea/verification/element_comparator"
      autoload :ComparisonResult, "lutaml/qea/verification/comparison_result"
      autoload :DocumentVerifier, "lutaml/qea/verification/document_verifier"
    end
  end
end
