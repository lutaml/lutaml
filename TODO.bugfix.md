# Bug Fixes (All Resolved)

## 1. DiagramTransformer overwrites resolved package_id with raw numeric ID [FIXED]

**File:** `lib/lutaml/qea/factory/diagram_transformer.rb`

Lines 34-39 correctly resolve the numeric `package_id` to a GUID (`"EAPK_..."`), but line 66
overwrote it with `ea_diagram.package_id` (a raw integer). Removed the overwrite.

## 2. Stereotype assigned as string instead of array in multiple transformers [FIXED]

`TopElement#stereotype` is declared `collection: true` (should be an array), but multiple
transformers assigned a bare string. lutaml-model doesn't auto-wrap. Downstream code calling
`.first` or `.include?` got string behavior (first character, substring match) instead of array.

Fixed in:
- QEA factory: class_transformer, data_type_transformer, enum_transformer, package_transformer, generalization_transformer
- XMI converter: xmi_to_uml.rb (all 5 assignments)
- Consumers: enhanced_formatter, tree_view_formatter, diagram_command, diagram_presenter, search_query

## 3. Dead ternary in ClassTransformer [FIXED]

`klass.type = is_text_class ? "Class" : "Class"` — both branches were identical.
Replaced with `klass.type = "Class"`.
