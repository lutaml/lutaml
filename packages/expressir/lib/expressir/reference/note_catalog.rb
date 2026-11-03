# frozen_string_literal: true

module Expressir
  module Reference
    # Catalog of Checker note ids, generated from the checker source so
    # the published guide cannot drift from the implementation.
    class NoteCatalog
      CHECKER_PATH = File.expand_path("../express/checker.rb", __dir__)
      NOTE_CALL = /note!\(:([a-z0-9_]+)/

      class << self
        def checker_path
          CHECKER_PATH
        end

        def entries
          File.read(CHECKER_PATH).scan(NOTE_CALL).flatten.tally.sort.to_h
        end

        def ids
          entries.keys
        end

        def render_adoc
          lines = [
            "= Checker note-id catalog",
            "",
            "// Generated from lib/expressir/express/checker.rb by",
            "// `rake reference:notes`. Do not edit by hand; the reference",
            "// spec fails when this file is stale.",
            "",
            "== Purpose",
            "",
            "Every note id the Checker can raise, with the number of call",
            "sites in the implementation. New checks use `:check_*` ids;",
            "the conformance-derived ids (`:check_expr_*`, `:check_dialect_*`)",
            "cite their clause in the note message.",
            "",
            '[cols="3,1", options="header"]',
            "|===",
            "| Note id | Call sites",
            "",
            *entries.map { |id, count| "| `#{id}` | #{count}" },
            "|===",
            "",
            "The catalog covers #{ids.size} note ids.",
            "",
          ]
          lines.join("\n")
        end
      end
    end
  end
end
