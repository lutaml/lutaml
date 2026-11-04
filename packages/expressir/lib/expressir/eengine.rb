module Expressir
  module Eengine
    autoload :ModifiedObject, "#{__dir__}/eengine/modified_object"
    autoload :ChangesSection, "#{__dir__}/eengine/changes_section"
    autoload :CompareReport, "#{__dir__}/eengine/compare_report"
    autoload :ArmCompareReport, "#{__dir__}/eengine/arm_compare_report"
    autoload :MimCompareReport, "#{__dir__}/eengine/mim_compare_report"
  end
end
