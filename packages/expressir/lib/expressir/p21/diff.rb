# frozen_string_literal: true

module Expressir
  module P21
    # Instance-level comparison of two populations (TODO.instance/03):
    # the population sibling of SchemaCompare. Instances are keyed by
    # their #id; a change is a keyword or parameter digest difference.
    module Diff
      Digest = Struct.new(:keyword, :params, keyword_init: true) do
        def to_s
          "#{keyword}(#{params.join(', ')})"
        end
      end

      module_function

      def diff(base, revised)
        added = (revised.instances.keys - base.instances.keys).sort
        removed = (base.instances.keys - revised.instances.keys).sort
        changed = (base.instances.keys & revised.instances.keys)
          .reject do |id|
            digest(base.instances[id]).to_s == digest(revised.instances[id]).to_s
          end.sort
        { added: added, removed: removed, changed: changed }
      end

      def digest(record)
        if record.is_a?(ComplexRecord)
          Digest.new(keyword: "__complex__",
                     params: record.records.map do |part|
                       Digest.new(keyword: part.keyword,
                                  params: part.params)
                     end)
        else
          Digest.new(keyword: record.keyword, params: record.params)
        end
      end
    end
  end
end
