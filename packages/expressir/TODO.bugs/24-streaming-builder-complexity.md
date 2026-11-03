# 24 — StreamingBuilder convert_ast_format is 190 lines with 5 levels of nesting

**Priority:** P3 (complexity; defer unless time allows)

## Problem

`lib/expressir/express/streaming_builder.rb:241-429` —
`convert_ast_format` is a 190-line method with deeply nested conditionals
for merging Parsanol's single-key-hash sequences.

## Fix

Split into named sub-methods for each pattern: merge-sequence,
repetition-unzip, str-concat.

## Acceptance

- No method in StreamingBuilder exceeds 30 lines.
- All streaming specs pass.
