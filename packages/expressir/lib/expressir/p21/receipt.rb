# frozen_string_literal: true

require "json"
require "digest"

module Expressir
  module P21
    # A validation receipt (TODO.instance/03): the deterministic,
    # citable record binding a dataset to a schema edition and a
    # validator run. Same manifest + same files → byte-identical
    # receipt.
    module Receipt
      module_function

      def build(manifest, results)
        files = results.keys.sort.map do |path|
          {
            "path" => path,
            "digest" => Digest::SHA256.hexdigest(File.read(path)),
            "notes" => results[path].map do |note|
              {
                "id" => note.id.to_s,
                "severity" => note.severity.to_s,
                "instance" => note.instance,
                "message" => note.message,
              }
            end,
          }
        end
        report = {
          "release" => manifest.release.to_s,
          "schema" => manifest.schema.to_s,
          "validator" => "expressir #{Expressir::VERSION}",
          "files" => files,
          "summary" => {
            "files" => files.size,
            "errors" => files.sum { |file| file["notes"].count { |n| n["severity"] == "error" } },
            "warnings" => files.sum { |file| file["notes"].count { |n| n["severity"] == "warning" } },
          },
        }
        JSON.generate(report)
      end
    end
  end
end
