# frozen_string_literal: true

module Expressir
  # Measurement tiers over the standards corpus (TODO.sota/07 part 2).
  module Conformance
    autoload :Trend, "#{__dir__}/conformance/trend"
  end
end
