# frozen_string_literal: true

require "lutaml/model"

Dir.glob(File.expand_path("./lml/**/*.rb", __dir__)).each do |file|
  require file
end

module Lutaml
  module Lml
    class Error < StandardError; end
  end
end
