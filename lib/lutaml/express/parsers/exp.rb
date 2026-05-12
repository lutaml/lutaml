# frozen_string_literal: true

require "expressir"
require "expressir/express/parser"
require "expressir/express/cache"

module Lutaml
  module Express
    module Parsers
      # Parses EXPRESS schema files (.exp) and cached repositories (.exp.cache).
      class Exp
        # @param io [File, IO] file object with path to .exp file
        # @param options [Hash] parsing options
        # @return [Expressir::Model::Repository]
        def self.parse(io, _options = {})
          Expressir::Express::Parser.from_files([io.path])
        end

        # @param path [String] path to cached .exp.cache file
        # @param options [Hash] parsing options
        # @return [Expressir::Model::Cache]
        def self.parse_cache(path, _options = {})
          Expressir::Express::Cache.from_file(path)
        end
      end
    end
  end
end
