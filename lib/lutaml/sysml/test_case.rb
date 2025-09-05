module Lutaml
  module Sysml
    class TestCase < Lutaml::Uml::TopElement
      attr_accessor :base_behavior, :verifies

      def name
        if !base_behavior.nil? && !base_behavior.name.nil?
          return base_behavior.name
        end

        nil
      end

      def full_name
        if !base_behavior.nil? && !base_behavior.name.nil?
          return base_behavior.full_name
        end

        nil
      end
    end
  end
end
