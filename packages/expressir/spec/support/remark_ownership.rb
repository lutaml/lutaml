# frozen_string_literal: true

module Expressir
  # Records which element each remark is attached to, so a formatter change
  # cannot move a remark into the wrong block while leaving it in the output.
  #
  # Conservation asks whether a remark survives. This asks where it landed.
  # The two miss different bugs: a remark that escapes a REPEAT loop and
  # reattaches to the enclosing function is still present, still spelled the
  # same, and still counted.
  module RemarkOwnership
    # Walks a parsed model and collects one entry per remark.
    #
    # This repeats `Express::ModelVisitor`'s traversal contract rather than
    # subclassing it, because a path has to name the attribute and index a
    # child was reached through. Without those, the THEN and ELSE branches of
    # an IF both read as `Statements::If/Statements::Assignment`, and a remark
    # moving from one branch to the other reports no move at all.
    class Trace
      # `tagged` is its own field rather than a sentinel in `format`, which
      # holds the RemarkInfo format and is nil for a tagged remark.
      Entry = Data.define(:path, :text, :format, :tagged, :placement, :region)

      # Tagged remarks live in a plain string collection on the element they
      # were bound to, separately from the RemarkInfo list.
      TAGGED_COLLECTION = :remarks
      UNTAGGED_COLLECTION = :untagged_remarks

      # @param model [Model::ModelElement]
      # @return [Array<Entry>] one per remark, in traversal order, with a
      #   node's untagged remarks ahead of its tagged ones
      def self.of(model)
        new.tap { |trace| trace.walk(model, "") }.entries
      end

      attr_reader :entries

      def initialize
        @entries = []
      end

      def walk(node, path)
        here = path.empty? ? label(node) : path
        record(node, here)

        node.class.attributes.each_key do |attr|
          next if Model::ModelElement::SKIP_ATTRIBUTES.include?(attr)

          descend(node.public_send(attr), attr, here)
        end
      end

      private

      def descend(value, attr, path)
        case value
        when Array
          value.each_with_index do |item, index|
            next unless item.is_a?(Model::ModelElement)

            walk(item, "#{path}/#{attr}[#{index}]#{label(item)}")
          end
        when Model::ModelElement
          walk(value, "#{path}/#{attr}#{label(value)}")
        end
      end

      def record(node, path)
        untagged = if node.respond_to?(UNTAGGED_COLLECTION)
                     Array(node.public_send(UNTAGGED_COLLECTION))
                   else
                     []
                   end

        record_untagged(untagged, path)
        record_tagged(node, untagged, path)
      end

      def record_untagged(untagged, path)
        untagged.each do |remark|
          next if remark.text.to_s.empty?

          @entries << Entry.new(path: path, text: remark.text,
                                format: remark.format, tagged: false,
                                placement: remark.placement,
                                region: remark.region)
        end
      end

      # `remarks` holds every remark's bare text, tagged or not: the attacher
      # dual-stores, mirroring each untagged text there as well. So a
      # genuinely tagged remark is what is left after subtracting the untagged
      # texts, which is how the formatter derives them too.
      #
      # A tagged remark carries only its text here; the element it hangs off
      # is the binding, which is exactly what this trace is comparing. Empty
      # text is kept, unlike untagged: `--"x"` and `--IP1:` bind to an element
      # and losing that binding is a real move.
      def record_tagged(node, untagged, path)
        return unless node.respond_to?(TAGGED_COLLECTION)

        # Empty untagged texts are counted here even though they are not
        # recorded above: `remarks` mirrors them too, and leaving them out
        # would surface a mirror as a tagged remark.
        mirrored = untagged.map(&:text).tally

        Array(node.public_send(TAGGED_COLLECTION)).compact.each do |text|
          if mirrored[text]&.positive?
            mirrored[text] -= 1
            next
          end

          @entries << Entry.new(path: path, text: text, format: nil,
                                tagged: true, placement: nil, region: nil)
        end
      end

      # The root carries the file it was read from, which differs between a
      # parse of a file and a parse of that file's formatted output.
      def label(node)
        return "ExpFile" if node.is_a?(Model::ExpFile)

        name = node.class.name.sub("Expressir::Model::", "")
        id = node.respond_to?(:id) ? node.id : nil
        id.to_s.empty? ? name : "#{name}(#{id})"
      end
    end

    # A remark's identity for this comparison: two remarks are the same remark
    # when their text, format and taggedness all agree.
    IDENTITY = ->(entry) { [entry.text, entry.format, entry.tagged] }

    module_function

    # Remarks whose identity survives a round trip but whose attachment
    # changed.
    #
    # @param before [Array<Trace::Entry>] from the source
    # @param after [Array<Trace::Entry>] from a parse of the formatted output
    # @return [Hash{Array => Array(Hash, Hash)}] identity => [was, now]
    def moved(before, after)
      was = places_by_identity(before)
      now = places_by_identity(after)

      (was.keys & now.keys).each_with_object({}) do |identity, moves|
        next if was[identity] == now[identity]
        # The formatter compacts remark-less ALIAS/REPEAT placeholder
        # statements, shifting later statement slots within the same
        # body; a place that matches once the slot numbers are elided
        # did not change which construct owns the remark.
        next if places_equal_modulo_statement_slots?(was[identity],
                                                     now[identity])

        moves[identity] = [was[identity], now[identity]]
      end
    end

    # Places equal when the only difference is the statement slot
    # numbers inside otherwise identical owner paths.
    def places_equal_modulo_statement_slots?(was_places, now_places)
      normalize = lambda do |places|
        places.each_with_object({}) do |pair, out|
          place = pair[0]
          count = pair[1]
          key =
            if place.is_a?(String)
              place.gsub(/statements\[\d+\]/, "statements[]")
            else
              place.map do |segment|
                segment.is_a?(String) ? segment.gsub(/statements\[\d+\]/, "statements[]") : segment
              end
            end
          out[key] = count
        end
      end
      normalize.call(was_places) == normalize.call(now_places)
    end

    # True when a move is the one the formatter is known to make: a remark
    # sitting between declarations is written outside its SCHEMA, so reparsing
    # attaches it to the file. Every other move means a remark changed which
    # construct it belongs to, which is a bug.
    #
    # @param move [Array(Hash, Hash)] the [was, now] pair from {moved}
    def schema_escape?(move)
      was, now = move
      departed = beyond(was, now)
      arrived = beyond(now, was)
      return false if departed.empty? || arrived.empty?
      return false unless departed.values.sum == arrived.values.sum

      departed.keys.all? { |place| schema_owned?(place) } &&
        arrived.keys.all? { |place| file_owned?(place) }
    end

    # Counted rather than sorted: placement is nil for some remarks and a
    # string for others, and sorting tuples that differ there raises.
    def places_by_identity(entries)
      entries.group_by(&IDENTITY).transform_values do |group|
        group.map { |e| [e.path, e.placement, e.region] }.tally
      end
    end

    # Places in +left+ beyond the copies +right+ also has, so that a move is
    # judged on what actually departed and arrived rather than on the copies
    # that stayed where they were.
    def beyond(left, right)
      left.each_with_object({}) do |(place, count), rest|
        remainder = count - right.fetch(place, 0)
        rest[place] = remainder if remainder.positive?
      end
    end

    # The id is optional because `label` omits the parentheses for a schema
    # with no id, and such a schema still escapes the same way.
    SCHEMA_OWNER =
      %r{\AExpFile/schemas\[\d+\]Declarations::Schema(?:\([^)]*\))?\z}

    def schema_owned?(place)
      path, placement, region = place
      path.match?(SCHEMA_OWNER) && placement.nil? && region.nil?
    end

    def file_owned?(place)
      path, placement, region = place
      path == "ExpFile" && placement.nil? && region.nil?
    end

    private_class_method :places_by_identity, :beyond, :schema_owned?,
                         :file_owned?
  end
end
