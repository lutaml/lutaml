module Expressir
  module Commands
    class Version < Base
      def run
        say Expressir::Version::VERSION
      end
    end
  end
end
