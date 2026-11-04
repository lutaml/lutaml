module Expressir
  module Model
    # Represents a remark with its format and optional tag
    # Supports both tail remarks (-- ...) and embedded remarks ((* ... *))
    # Can include optional tags for associating remarks with specific items
    class RemarkInfo < Lutaml::Model::Serializable
      attribute :text, :string
      attribute :format, :string, default: RemarkFormat::EMBEDDED
      attribute :tag, :string # optional remark tag like "entity.attr"
      # See RemarkPlacement. nil = legacy placement.
      attribute :placement, :string
      # Qualifies the placement. For TRAILING, which body of the owner the
      # remark closes, named by that body's attribute. For INLINE,
      # RemarkPlacement::OPENER_REGION when it trailed a compound statement's
      # opening line rather than a whole statement.
      attribute :region, :string
      attribute :source_offset, :integer # byte offset in source text

      # Check if this is a tail remark
      # @return [Boolean] True if format is 'tail'
      def tail?
        format == RemarkFormat::TAIL
      end

      # Check if this is an embedded remark
      # @return [Boolean] True if format is 'embedded'
      def embedded?
        format == RemarkFormat::EMBEDDED
      end

      # Check if this remark has a tag
      # @return [Boolean] True if tag is present
      def tagged?
        !tag.nil? && !tag.empty?
      end

      # Check if this remark should be emitted above its owning statement
      # @return [Boolean] True if placement is 'leading'
      def leading?
        placement == RemarkPlacement::LEADING
      end

      # Check if this remark trails its owning statement on the same line
      # @return [Boolean] True if placement is 'inline'
      def inline?
        placement == RemarkPlacement::INLINE
      end

      # Check if this remark trailed the opening line of a statement spanning
      # several lines, as in `IF x THEN -- why`
      # @return [Boolean]
      def opener?
        inline? && region == RemarkPlacement::OPENER_REGION
      end

      # Check if this INLINE remark belongs after a mid-construct keyword of
      # its owning construct — `ELSE -- why`, `OTHERWISE : -- why` — rather
      # than after the statement's closing keyword.
      # @param name [Symbol, String] a RemarkPlacement region constant
      # @return [Boolean]
      def inline_region?(name)
        inline? && region == name.to_s
      end

      # Check if this remark closes the given body of its owning node
      # @param name [Symbol, String] region attribute name
      # @return [Boolean]
      def trailing_region?(name)
        placement == RemarkPlacement::TRAILING && region == name.to_s
      end

      # YAML serialization
      yaml do
        map "text", to: :text
        map "format", to: :format
        map "tag", to: :tag
        map "placement", to: :placement
        map "region", to: :region
      end

      # XML serialization
      xml do
        element "remark_info"
        map_element "text", to: :text
        map_element "format", to: :format
        map_element "tag", to: :tag
        map_element "placement", to: :placement
        map_element "region", to: :region
      end
    end
  end
end
