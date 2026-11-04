# 29 — ValidateAscii is a 604-line god class with inline inner classes

**Priority:** P2 (god class)
**Status:** DONE

## Problem

`validate_ascii.rb` was 549 lines with 3 sibling classes defined inline:
NonAsciiCharacter, FileViolations, NonAsciiViolationCollection.

## Fix

Extracted the three inner classes to separate files:
- `lib/expressir/commands/non_ascii_character.rb` (50 lines)
- `lib/expressir/commands/file_violations.rb` (71 lines)
- `lib/expressir/commands/non_ascii_violation_collection.rb` (349 lines)

`validate_ascii.rb` now contains only the ValidateAscii command class
(94 lines). Autoloads added to `lib/expressir/commands.rb`.

## Acceptance

- validate_ascii.rb under 100 lines.
- All 26 validate_ascii specs pass.
