module Expressir
  module Model
    module Identifier
      def self.included(mod)
        # Auto-include markers - all Identifier types have id and can have remark_items and remarks
        mod.include(HasId)
        mod.include(HasRemarkItems)
        mod.include(HasRemarks)

        mod.attribute :id, :string
        mod.attribute :remarks, :string, collection: true, initialize_empty: true
        mod.attribute :remark_items,
                      ::Expressir::Model::Declarations::RemarkItem, collection: true, initialize_empty: true
        mod.attribute :untagged_remarks, ::Expressir::Model::RemarkInfo,
                      collection: true, initialize_empty: true

        mod.key_value do
          map "id", to: :id
          map "remarks", to: :remarks
          map "remark_items", to: :remark_items
          map "untagged_remarks", to: :untagged_remarks
        end
      end
    end
  end
end
