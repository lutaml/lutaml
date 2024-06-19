# frozen_string_literal: true

require "hashie"

module Lutaml
  module Uml
    module Serializers
      class Base < Hashie::Dash
        include Hashie::Extensions::Dash::PropertyTranslation
        include Hashie::Extensions::Dash::IndifferentAccess
        include Hashie::Extensions::Dash::Coercion
        include Hashie::Extensions::IgnoreUndeclared
      end
    end
  end
end
