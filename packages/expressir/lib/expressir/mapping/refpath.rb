# frozen_string_literal: true

module Expressir
  module Mapping
    # Formalization, parser, and validator for MIM reference paths
    # (expressir#88): the "Reference path" sections of module
    # mapping.yaml files, written in the EXPRESS mapping language
    # (ELF 5006:2025). Until now the notation was prose for humans
    # only; this makes it machine-readable and checks it against real
    # schemas.
    #
    # Grammar (ELF 5006 §5; corpus-verified over all module
    # mapping.yaml refpaths):
    #   path       := step+
    #   step       := [link] node [index] [constraint]
    #               | constraint
    #               | MARKER
    #   link       := "->" | "<-" | "<=" | "=>" | "*>"
    #               | "<*" | "=" NAME (relation to the previous node)
    #   node       := NAME ["." ATTRIBUTE]
    #               | LINK                    (<<express:SCHEMA.ITEM,ITEM>>,
    #                                          #460: a link may stand
    #                                          wherever a declaration
    #                                          is referenced)
    #   index      := "[" ("i" | DIGITS) "]"
    #   constraint := ["!"] "{" NAME [NAME "."] "=" STRING "}"
    #   supertype  := "||" NAME "||"          (§5 supertype entity marker)
    #   tree       := "*" NAME "*"            (§5 relationship tree marker)
    #   MARKER     := "{" | "}" | "[" | "]" | "(" | ")" | ":" | "|" | "!"
    #               | "," | "/" | "*" | "<" | ">" (grouping/annotation;
    #                                               never breaks a
    #                                               pending link; the §5
    #                                               required-path marker
    #                                               "<path>" is transparent
    #                                               — its contents validate
    #                                               in the running context)
    #
    # Validation (ELF 5006 §8): a running path context tracks the
    # entity a path is "at"; each step must connect to it, attribute
    # navigations must be type-compatible with their target, and
    # constraints must reference an entity in the path context with an
    # existing, constrainable attribute whose type accepts the literal.
    module RefPath
      # Wire-name mapping is declared here so a parsed path can itself
      # be serialized with lutaml-model.
      class Step < Lutaml::Model::Serializable
        attribute :operator, :string
        attribute :name, :string
        attribute :attribute, :string
        attribute :index, :string
        attribute :literal, :string
        attribute :link, :string
        attribute :negated, :boolean
        # For constraint steps: the entity owning the constrained
        # attribute when it differs from the constrained entity.
        attribute :owner, :string

        key_value do
          map "operator", to: :operator
          map "name", to: :name
          map "attribute", to: :attribute
          map "index", to: :index
          map "literal", to: :literal
          map "link", to: :link
          map "negated", to: :negated
          map "owner", to: :owner
        end
      end

      class Path < Lutaml::Model::Serializable
        attribute :steps, Step, collection: true
        attribute :parse_errors, :string, collection: true

        key_value do
          map "steps", to: :steps
          map "parse_errors", to: :parse_errors
        end
      end

      # ELF 5006 §8 "Validation output": one structured verdict per
      # path, serializable to YAML/JSON for the toolchain.
      class ReportIssue < Lutaml::Model::Serializable
        attribute :step, :integer
        attribute :message, :string

        key_value do
          map "step", to: :step
          map "message", to: :message
        end
      end

      class Report < Lutaml::Model::Serializable
        attribute :status, :string
        attribute :start, :string
        attribute :ending, :string
        attribute :steps, :integer
        attribute :entities, :string, collection: true
        attribute :issues, ReportIssue, collection: true

        key_value do
          map "status", to: :status
          map "start", to: :start
          map "ending", to: :ending
          map "steps", to: :steps
          map "entities", to: :entities
          map "issues", to: :issues
        end
      end

      EXPRESS_LINK_PATH = /\A<<express:([^,>]+)(?:,[^>]+)?>>\z/
      private_constant :EXPRESS_LINK_PATH

      TOKEN = /<<express:[^,>]+(?:,[^>]+)?>>|->|<-|<=|=>|\*>|<\*|\|\||!?\{|[{}\[\]()=:|!,*\/<>]|'(?:''|[^'])*'|\w+(?:\.\w+)?/
      MARKERS = ["{", "}", "[", "]", "(", ")", ":", "|", "!", ",", "/",
                 "*", "<", ">", "MAPPING_OF", "!{"].freeze
      LINKS = ["->", "<-", "<=", "=>", "*>", "<*"].freeze
      DECLARATION_COLLECTIONS = %i[types entities].freeze
      private_constant :TOKEN, :MARKERS, :LINKS, :DECLARATION_COLLECTIONS

      Issue = Struct.new(:step, :message, keyword_init: true)

      module_function

      # @return [Report] the structured VALID/INVALID verdict for
      #   +content+ (ELF 5006 §8 Validation output), carrying the
      #   traversed entities and every collected issue.
      def report(content, repository, start: nil)
        path = parse(content)
        issues = validate(path, repository, start: start)
        entities = path.steps.filter_map(&:name).uniq
        Report.new(
          status: (issues.empty? && path.parse_errors.empty? ? "VALID" : "INVALID"),
          start: start || entities.first,
          ending: entities.last,
          steps: path.steps.size,
          entities: entities,
          issues: issues.map { |i| ReportIssue.new(step: i.step, message: i.message) },
        )
      end

      # @param content [String] the mapping.yaml refpath content block
      # @return [Path]
      def parse(content)
        tokens = content.to_s.scan(TOKEN)
        steps = []
        errors = []
        pending_link = nil
        pending_type_assign = false
        i = 0
        while i < tokens.length
          token = tokens[i]
          case token
          when "||"
            name_token = tokens[i + 1]
            if name_token&.match?(/\A\w+\z/) && tokens[i + 2] == "||"
              steps << Step.new(operator: "||", name: name_token)
              i += 2
            else
              errors << "supertype marker '||' without an entity name"
            end
          when "!{"
            step, consumed = parse_constraint(tokens[i..], negated: true)
            steps << step
            i += consumed
            pending_link = nil
            pending_type_assign = false
            next
          when "{"
            step, consumed = parse_constraint(tokens[i..], negated: false)
            steps << step
            i += consumed
            pending_link = nil
            pending_type_assign = false
            next
          when *LINKS
            pending_link = token
          when "="
            literal = tokens[i + 1]
            if literal&.start_with?("'")
              attach(steps, errors, :literal, literal)
              i += 1
            elsif literal.nil?
              errors << "constraint '=' with nothing after it"
            else
              # `x = Type` type assignment: the following node (however
              # many markers it sits behind, e.g. /MAPPING_OF(X)/)
              # carries the "=" link.
              pending_type_assign = true
            end
          when "["
            if index_token?(tokens[i + 1])
              attach(steps, errors, :index, tokens[i + 1])
              i += 2 # the index token and the closing "]"
            else
              steps << Step.new(operator: "[")
            end
          when "*"
            name_token = tokens[i + 1]
            if name_token&.match?(/\A\w+\z/) && tokens[i + 2] == "*"
              steps << Step.new(operator: "*", name: name_token)
              i += 2
            else
              steps << Step.new(operator: token)
            end
          when *MARKERS
            steps << Step.new(operator: token)
          when /\A<<express:/
            steps << Step.new(operator: pending_link, link: token)
            pending_link = nil
            pending_type_assign = false
          else
            name, _, attribute = token.partition(".")
            operator = pending_link || ("=" if pending_type_assign)
            steps << Step.new(operator: operator, name: name,
                              attribute: attribute.empty? ? nil : attribute)
            pending_link = nil
            pending_type_assign = false
          end
          i += 1
        end
        Path.new(steps: steps, parse_errors: errors)
      end

      # A constraint block from +tokens+ (which start at "{" or "!{"):
      # "{entity" or "{entity attr = literal}". Returns
      # [Step, tokens_consumed].
      def parse_constraint(tokens, negated:)
        inner = []
        consumed = 1
        tokens[1..].each do |token|
          consumed += 1
          break if token == "}"

          inner << token
        end
        eq = inner.index("=")
        value = eq && inner[eq + 1]
        literal = value || inner.find { |t| t.start_with?("'") }
        names = inner.select { |t| t.match?(/\A\w+(\.\w+)?\z/) && !t.start_with?("'") }
        qualified = names.find { |t| t.include?(".") }
        entity = if qualified && names.size == 1
                   # {entity.attr = value} with the entity named only inside
                   # the qualified reference
                   qualified.split(".", 2)[0]
                 else
                   names.find { |t| !t.include?(".") }
                 end
        owner, attribute = qualified ? qualified.split(".", 2) : [nil, nil]
        owner = nil if entity && owner&.safe_downcase == entity.safe_downcase
        step = Step.new(operator: "{", name: entity,
                        attribute: attribute, literal: literal,
                        negated: negated, owner: owner)
        [step, consumed]
      end

      def index_token?(token)
        token == "i" || token&.match?(/\A\d+\z/)
      end

      # Attach an index or constraint literal to the most recent node
      # step that does not carry one yet.
      def attach(steps, errors, field, value)
        step = steps.reverse.each.find { |s| s.name && !s.public_send(field) }
        if step
          step.public_send("#{field}=", value)
        else
          case field
          when :index then errors << "aggregate index [#{value}] has no node"
          when :literal then errors << "constraint #{value} has no node"
          end
        end
      end

      # Validate a parsed path against a repository. Issues reference
      # the step index they attach to. +start+ names the ARM entity the
      # path is expected to begin at (the ae entity); when given and
      # the path's first entity differs, a warning-level issue is
      # recorded (ELF 5006 §8: the rule "may be relaxed for attribute
      # mappings").
      # @return [Array<Issue>]
      def validate(path, repository, start: nil)
        by_name = name_index(repository)
        issues = []
        ctx = nil
        seen = {}
        last_qualified = nil
        path.steps.each_with_index do |step, pos|
          # markers never break the running link, mirroring parse
          next if marker_step?(step)

          if step.link
            issues.concat(check_link_step(step, pos, repository))
            prev = preceding_name(steps_before(path, pos))
            if step.name
              check_exists(issues, pos, step.name, by_name)
              ctx = step.name&.safe_downcase
            elsif prev
              ctx = prev&.safe_downcase
            end
            last_qualified = nil
            next
          end

          case step.operator
          when "(", ")"
            # alternative sections: each starts a fresh path context
            ctx = nil
            last_qualified = nil
          when "{"
            issues.concat(check_constraint(step, pos, ctx, seen, by_name))
          when "<=", "=>"
            issues.concat(relation_issues(step, pos, ctx, by_name))
            ctx = step.name&.safe_downcase
          when "->"
            issues.concat(forward_issues(step, pos, ctx, last_qualified, by_name))
            ctx = step.name&.safe_downcase
            last_qualified = nil
          when "<-"
            issues.concat(inverse_issues(step, pos, ctx, by_name))
            ctx = step.name&.safe_downcase
            last_qualified = step.attribute ? step : nil
          when "*>", "<*"
            issues.concat(select_extension_issues(step, pos, ctx, by_name))
            ctx = step.name&.safe_downcase
          when "||"
            issues.concat(supertype_marker_issues(step, pos, ctx, by_name))
            if step.name
              seen[step.name.safe_downcase] = true
              ctx = step.name.safe_downcase
            end
          when "*"
            issues.concat(tree_marker_issues(step, pos, by_name))
          else
            issues.concat(check_step(step, pos, ctx, last_qualified, by_name))
            if step.name
              seen[step.name.safe_downcase] = true
              last_qualified = step.attribute ? step : nil
              ctx = step.name.safe_downcase unless ctx == step.name.safe_downcase && step.attribute
            end
          end
        end
        if start && path.steps.any?(&:name)
          first = path.steps.find { |s| s.name && !s.link }
          if first && first.name&.safe_downcase != start.safe_downcase
            issues << Issue.new(step: 0,
                                message: "path starts at '#{first.name}' but " \
                                         "the mapped entity is '#{start}'")
          end
        end
        issues
      end

      def marker_step?(step)
        step.name.nil? && step.attribute.nil? && step.link.nil? &&
          step.operator != "{" && step.operator != "(" && step.operator != ")"
      end

      def steps_before(path, pos)
        path.steps[0...pos].reverse_each
      end

      def preceding_name(steps)
        steps.find { |s| s.name && !s.link }&.name
      end

      def check_exists(issues, pos, name, by_name)
        return if name.nil? || by_name.key?(name.safe_downcase)

        issues << Issue.new(step: pos,
                            message: "unknown type '#{name}'")
      end

      # ELF 5006 §8 constraint validation: the constrained entity must
      # exist and appear in the path context; the constrained attribute
      # must exist on it and be constrainable (not DERIVED/INVERSE);
      # the literal must type-check against the attribute's type.
      def check_constraint(step, pos, ctx, seen, by_name)
        issues = []
        entity = step.name
        check_exists(issues, pos, entity, by_name)
        return issues if entity.nil?

        key = entity.safe_downcase
        in_context = (ctx && ctx == key) || seen[key]
        unless in_context
          issues << Issue.new(step: pos,
                              message: "constraint entity '#{entity}' is not " \
                                       "in the path context")
        end

        owner_key = (step.owner || entity).safe_downcase
        decl = by_name[owner_key]&.last
        return issues unless decl.is_a?(Model::Declarations::Entity)

        if step.attribute
          attribute = find_attribute(decl, step.attribute, by_name)
          unless attribute
            issues << Issue.new(step: pos,
                                message: "entity '#{entity}' has no attribute " \
                                         "'#{step.attribute}'")
            return issues
          end

          if attribute.respond_to?(:kind) &&
              [Model::Declarations::Attribute::DERIVED, Model::Declarations::Attribute::INVERSE].include?(attribute.kind)
            issues << Issue.new(step: pos,
                                message: "attribute '#{entity}." \
                                         "#{step.attribute}' is " \
                                         "#{attribute.kind} and cannot be " \
                                         "constrained")
          end

          type = attribute.respond_to?(:type) ? attribute.type : nil
          issue = value_type_issue(type, step.literal, entity,
                                   step.attribute, by_name)
          issues << Issue.new(step: pos, message: issue) if issue
        elsif step.literal
          issues << Issue.new(step: pos,
                              message: "constraint literal '#{step.literal}' " \
                                       "has no attribute")
        end
        issues
      end

      # ELF 5006 §8 value-type compatibility table.
      def value_type_issue(type, literal, entity, attribute, by_name)
        return nil if literal.nil?

        kind = value_kind(literal)
        resolved = resolve_type_name(type, by_name)
        case resolved
        when :string
          return nil if kind == :string

          "value #{literal} is not a single-quoted string " \
            "(#{entity}.#{attribute} is a STRING)"
        when :integer
          return nil if kind == :integer

          "value #{literal} is not an unquoted integer " \
            "(#{entity}.#{attribute} is an INTEGER)"
        when :real, :number
          return nil if %i[integer real].include?(kind)

          "value #{literal} is not an unquoted number " \
            "(#{entity}.#{attribute} is a #{resolved.to_s.upcase})"
        when :boolean
          return nil if kind == :boolean

          "value #{literal} is not TRUE or FALSE " \
            "(#{entity}.#{attribute} is a BOOLEAN)"
        when :logical
          return nil if %i[boolean logical].include?(kind)

          "value #{literal} is not TRUE, FALSE or UNKNOWN " \
            "(#{entity}.#{attribute} is a LOGICAL)"
        when :enumeration
          return nil if kind == :enumeration && enumeration_item?(type, literal, by_name)

          "value #{literal} is not an item of the enumeration type of " \
            "#{entity}.#{attribute}"
        when :select
          nil # any value shape may be legitimate against a SELECT arm
        end
      end

      def value_kind(literal)
        case literal
        when /\A'/ then :string
        when /\A(TRUE|FALSE)\z/ then :boolean
        when /\AUNKNOWN\z/ then :logical
        when /\A-?\d+\z/ then :integer
        when /\A-?\d+\.\d+\z/ then :real
        else :enumeration
        end
      end

      # Resolve a parsed type node to a value-domain tag for the
      # §8 table, or nil when the type cannot be determined.
      def resolve_type_name(type, by_name)
        case type
        when Model::DataTypes::Boolean then :boolean
        when Model::DataTypes::Logical then :logical
        when Model::DataTypes::String then :string
        when Model::DataTypes::Integer then :integer
        when Model::DataTypes::Real then :real
        when Model::DataTypes::Number then :number
        when Model::DataTypes::Enumeration then :enumeration
        when Model::DataTypes::Select then :select
        when Model::ModelElement
          return resolve_type_name(type.base_type, by_name) if type.respond_to?(:base_type) && type.base_type

          id = if type.respond_to?(:base_path) && type.base_path
                 type.base_path.split(".").last
               elsif type.respond_to?(:id)
                 type.id
               end
          return nil unless id

          decl = by_name[id.safe_downcase]&.last
          return nil unless decl.is_a?(Model::Declarations::Type)

          resolve_type_name(decl.underlying_type, by_name)
        end
      end

      def enumeration_item?(type, literal, by_name)
        item = literal.delete_prefix("'").delete_suffix("'").safe_downcase
        case type
        when Model::DataTypes::Enumeration
          type.items.to_a.any? { |i| i.id&.safe_downcase == item }
        when Model::ModelElement
          return enumeration_item?(type.base_type, literal, by_name) if type.respond_to?(:base_type) && type.base_type

          id = if type.respond_to?(:base_path) && type.base_path
                 type.base_path.split(".").last
               elsif type.respond_to?(:id)
                 type.id
               end
          decl = id && by_name[id.safe_downcase]&.last
          decl.is_a?(Model::Declarations::Type) &&
            enumeration_item?(decl.underlying_type, literal, by_name)
        end
      end

      # ELF 5006 §5 supertype entity marker: `||supertype||` names an
      # entity that must exist and, when the path has a running
      # context, be a supertype of (or equal to) that context entity.
      def supertype_marker_issues(step, pos, ctx, by_name)
        issues = []
        entity = step.name
        check_exists(issues, pos, entity, by_name)
        return issues if entity.nil?

        decl = by_name[entity.safe_downcase]&.last
        return issues unless decl.is_a?(Model::Declarations::Entity)

        context_decl = ctx && by_name[ctx]&.last
        if context_decl.is_a?(Model::Declarations::Entity) &&
            !entity_reaches?(context_decl, entity.safe_downcase, by_name,
                             {}.compare_by_identity)
          issues << Issue.new(step: pos,
                              message: "'#{entity}' is not a supertype of " \
                                       "'#{ctx}'")
        end
        issues
      end

      # ELF 5006 §5 relationship tree marker: `*relationship*` names an
      # entity whose instances may assemble into a tree; the path
      # between it and the related entities is implied, so only the
      # entity's existence is checkable.
      def tree_marker_issues(step, pos, by_name)
        issues = []
        check_exists(issues, pos, step.name, by_name)
        issues
      end

      # ELF 5006 §8 navigation validation with a running context: the
      # attribute must exist on the context entity, and its type must
      # be able to reference the step's target entity.
      def forward_issues(step, pos, ctx, last_qualified, by_name)
        issues = []
        unless ctx
          issues << Issue.new(step: pos,
                              message: "'->' with no preceding entity in the " \
                                       "path context")
          return issues
        end

        owner = by_name[ctx]&.last
        return issues unless owner.is_a?(Model::Declarations::Entity)

        attr_name = last_qualified&.attribute || step.attribute
        if attr_name.nil?
          issues << Issue.new(step: pos,
                              message: "'->' requires an attribute-qualified " \
                                       "node before it")
          return issues
        end

        attribute = find_attribute(owner, attr_name, by_name)
        unless attribute
          issues << Issue.new(step: pos,
                              message: "entity '#{owner.id}' has no attribute " \
                                       "'#{attr_name}'")
          return issues
        end

        issues.concat(target_compat_issues(attribute, step, pos, ctx, by_name))
        issues
      end

      def inverse_issues(step, pos, ctx, by_name)
        issues = []
        entity = step.name
        check_exists(issues, pos, entity, by_name)
        return issues if entity.nil?

        decl = by_name[entity.safe_downcase]&.last
        return issues unless decl.is_a?(Model::Declarations::Entity)

        attr_name = step.attribute
        if attr_name.nil?
          issues << Issue.new(step: pos,
                              message: "'<-' requires an attribute-qualified " \
                                       "node after it")
          return issues
        end

        attribute = find_attribute(decl, attr_name, by_name)
        unless attribute
          issues << Issue.new(step: pos,
                              message: "entity '#{entity}' has no attribute " \
                                       "'#{attr_name}'")
          return issues
        end

        if ctx
          issues.concat(target_compat_issues(attribute, step, pos, ctx, by_name,
                                             inverse: true))
        end
        issues
      end

      # ELF 5006 §8: the attribute type must reference the target
      # entity, a supertype of it, or a SELECT whose options reach it.
      # `ctx` is the target of the navigation either way: for `->` the
      # step names it; for `<-` the path context carries it.
      def target_compat_issues(attribute, step, pos, ctx, by_name, inverse: false)
        type = attribute.respond_to?(:type) ? attribute.type : nil
        target = inverse ? ctx : step.name
        return [] if type.nil? || target.nil?
        return [] if references_entity?(type, target, by_name, {}.compare_by_identity)

        owner = attribute.parent.respond_to?(:id) ? attribute.parent.id : nil
        [Issue.new(step: pos,
                   message: "attribute '#{"#{owner}." if owner}" \
                            "#{attribute.id}' cannot reference '#{target}'")]
      end

      def references_entity?(type, target, by_name, seen)
        return false if type.nil? || seen[type]

        seen[type] = true
        if type.is_a?(Model::References::SimpleReference)
          id = type.respond_to?(:base_path) && type.base_path ? type.base_path.to_s.split(".").last : type.id
          return false if id.nil?

          key = id.safe_downcase
          return true if key == target

          decl = by_name[key]&.last
          return select_reaches?(decl, target, by_name, seen) if decl.is_a?(Model::Declarations::Type)

          return entity_reaches?(decl, target, by_name, seen)
        end
        if type.respond_to?(:base_type) && type.base_type
          return references_entity?(type.base_type, target, by_name, seen)
        end
        if type.is_a?(Model::DataTypes::Select)
          return type.items.to_a.any? do |item|
            id = item.respond_to?(:id) ? item.id&.safe_downcase : nil
            next false if id.nil?
            next true if id == target

            decl = by_name[id]&.last
            decl ? entity_reaches?(decl, target, by_name, seen) : false
          end
        end

        false
      end

      def select_reaches?(type_decl, target, by_name, seen)
        return false unless type_decl.is_a?(Model::Declarations::Type)

        underlying = type_decl.underlying_type
        references_entity?(underlying, target, by_name, seen)
      end

      # target is a subtype of the referenced entity decl (or equal).
      def entity_reaches?(decl, target, by_name, _seen)
        return false unless decl.is_a?(Model::Declarations::Entity)

        key = decl.id&.safe_downcase
        return true if key == target

        supertype_ids(decl, by_name).any? { |s| s&.safe_downcase == target }
      end

      def select_extension_issues(step, pos, ctx, by_name)
        issues = []
        check_exists(issues, pos, step.name, by_name)
        return issues if step.name.nil? || ctx.nil?

        base = by_name[ctx]&.last
        ext = by_name[step.name.safe_downcase]&.last
        return issues unless base.is_a?(Model::Declarations::Type) &&
          ext.is_a?(Model::Declarations::Type)

        return issues if select_extends?(ext, base, by_name, {}.compare_by_identity)

        issues << Issue.new(step: pos,
                            message: "SELECT '#{step.name}' does not extend '#{ctx}'")
        issues
      end

      # select_b <* select_a / select_a *> select_b: select_b extends
      # select_a when select_b's BASED ON chain reaches select_a.
      def select_extends?(ext, base, by_name, seen)
        return false if seen[ext]

        seen[ext] = true
        underlying = ext.underlying_type
        return false unless underlying.is_a?(Model::DataTypes::Select)

        based = underlying.based_on
        raw = based && (based.respond_to?(:base_path) ? based.base_path : based.id)
        based_id = raw && raw.to_s.split(".").last
        return true if based_id&.safe_downcase == base.id&.safe_downcase

        based_decl = based_id && by_name[based_id.safe_downcase]&.last
        based_decl ? select_extends?(based_decl, base, by_name, seen) : false
      end

      def relation_issues(step, pos, ctx, by_name)
        target = by_name[step.name&.safe_downcase]&.last
        source = ctx && by_name[ctx]&.last
        return [] unless source.is_a?(Model::Declarations::Entity) &&
          target.is_a?(Model::Declarations::Entity)

        if step.operator == "<="
          return [] if supertype_ids(source, by_name)
            .any? { |id| id&.safe_downcase == step.name&.safe_downcase }

          [Issue.new(step: pos,
                     message: "'#{ctx}' is not a subtype of '#{step.name}'")]
        else
          return [] if supertype_ids(target, by_name)
            .any? { |id| id&.safe_downcase == ctx }

          [Issue.new(step: pos,
                     message: "'#{step.name}' is not a subtype of '#{ctx}'")]
        end
      end

      def check_step(step, pos, ctx, _last_qualified, by_name)
        found = by_name[step.name&.safe_downcase]
        return [Issue.new(step: pos, message: "unknown type '#{step.name}'")] unless found

        issues = attribute_issues(step, pos, found[1], by_name)
        issues.concat(bare_continuity_issue(step, pos, ctx, found, by_name))
        issues
      end

      # ELF 5006 §8 navigation continuity: a bare node naming a
      # different entity than the context must still be related to it
      # (either one a supertype of the other).
      def bare_continuity_issue(step, pos, ctx, found, by_name)
        return [] unless ctx
        return [] if ctx == step.name&.safe_downcase

        decl = found[1]
        return [] unless decl.is_a?(Model::Declarations::Entity)

        down = ->(id) { id&.safe_downcase }
        if supertype_ids(decl, by_name).any? { |id| down.(id) == ctx }
          return []
        end

        ctx_decl = by_name[ctx]&.last
        if ctx_decl.is_a?(Model::Declarations::Entity) &&
            supertype_ids(ctx_decl, by_name).any? { |id| down.(id) == decl.id&.safe_downcase }
          return []
        end

        [Issue.new(step: pos,
                   message: "'#{step.name}' breaks navigation continuity " \
                            "(context is '#{ctx}')")]
      end

      EXPRESS_BUILTINS = %w[NUMBER INTEGER REAL STRING BOOLEAN LOGICAL
                            BINARY].freeze
      private_constant :EXPRESS_BUILTINS

      def name_index(repository)
        index = EXPRESS_BUILTINS.to_h { |b| [b.downcase, [nil, nil]] }
        repository.schemas.flat_map do |schema|
          DECLARATION_COLLECTIONS.flat_map do |coll|
            Array(schema.public_send(coll))
              .select { |d| d.respond_to?(:id) && d.id }
              .map { |d| [d.id.safe_downcase, [schema, d]] }
          end
        end.each { |pair| index[pair[0]] = pair[1] }
        index
      end

      # Validate links in aa.assertion_to (#460) and ae/sc entries.
      def check_link_step(step, pos, repository)
        parts = step.link.match(EXPRESS_LINK_PATH)
        return [Issue.new(step: pos, message: "malformed link '#{step.link}'")] unless parts

        schema_id, item_id = parts[1].split(".", 2).compact
        schema = repository.schemas
          .find { |s| s.id&.safe_downcase == schema_id&.safe_downcase }
        unless schema
          return [Issue.new(step: pos,
                            message: "unknown schema '#{schema_id}' in #{step.link}")]
        end

        return [] if item_id.nil?
        return [] if Expressir::Mapping.item_declared?(schema, item_id)

        [Issue.new(step: pos,
                   message: "schema '#{schema_id}' does not declare " \
                            "'#{item_id}' (#{step.link})")]
      end

      def attribute_issues(step, pos, decl, by_name)
        return [] unless step.attribute

        unless decl.is_a?(Model::Declarations::Entity)
          return [Issue.new(step: pos,
                            message: "'#{step.name}' is not an entity, " \
                                     "cannot carry '#{step.name}.#{step.attribute}'")]
        end

        attribute = find_attribute(decl, step.attribute, by_name)
        unless attribute
          return [Issue.new(step: pos,
                            message: "entity '#{step.name}' has no attribute " \
                                     "'#{step.attribute}'")]
        end

        aggregate_issue(step, pos, attribute)
      end

      # Direct or inherited attribute: inheritance follows the
      # subtype_of chain, resolved through the repository-wide index.
      def find_attribute(entity, attribute_id, by_name)
        key = attribute_id.safe_downcase
        supertype_chain(entity, by_name).lazy.flat_map do |candidate|
          Array(candidate.attributes)
        end.find { |a| a.id&.safe_downcase == key }
      end

      def supertype_chain(entity, by_name)
        seen = {}.compare_by_identity
        queue = [entity]
        result = []
        until queue.empty?
          current = queue.shift
          next if seen[current]

          seen[current] = true
          result << current
          current.subtype_of.to_a.each do |ref|
            sup = by_name[ref.respond_to?(:id) ? ref.id&.safe_downcase : nil]&.last
            queue << sup if sup.is_a?(Model::Declarations::Entity)
          end
        end
        result
      end

      def aggregate_issue(step, pos, attribute)
        return [] unless step.index
        return [] if attribute.type.respond_to?(:bound1)

        [Issue.new(step: pos,
                   message: "'#{step.name}.#{step.attribute}' is not an " \
                            "aggregate but carries [#{step.index}]")]
      end

      # ELF 5006 §8 subtype/supertype relations, resolved through the
      # repository-wide index so inherited chains (including
      # cross-schema USE FROM) walk correctly.
      def supertype_ids(entity, by_name)
        seen = {}.compare_by_identity
        queue = [entity]
        names = []
        until queue.empty?
          current = queue.shift
          next if seen[current]

          seen[current] = true
          direct = current.subtype_of.to_a.filter_map do |ref|
            ref.respond_to?(:id) ? ref.id : nil
          end
          leaves = expression_leaves(current.supertype_expression)
            .filter_map { |leaf| leaf.respond_to?(:id) ? leaf.id : nil }
          names.concat(direct)
          names.concat(leaves)
          direct.concat(leaves).each do |id|
            sup = by_name[id&.safe_downcase]&.last
            queue << sup if sup.is_a?(Model::Declarations::Entity)
          end
        end
        names.uniq
      end

      # Leaf reference nodes of a supertype expression tree.
      def expression_leaves(expr)
        return [] unless expr

        if expr.respond_to?(:operands)
          Array(expr.operands).flat_map { |o| expression_leaves(o) }
        elsif expr.respond_to?(:operand1)
          expression_leaves(expr.operand1) + expression_leaves(expr.operand2)
        elsif expr.respond_to?(:id) && expr.id
          [expr]
        else
          []
        end
      end
    end
  end
end
