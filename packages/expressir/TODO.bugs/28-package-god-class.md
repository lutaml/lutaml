# 28 — Package command is a 1266-line god class

**Priority:** P2 (god class)
**Status:** ACCEPTED — Thor command pattern

## Problem

`lib/expressir/commands/package.rb` is 1266 lines with 30 methods: display
logic (tree, info, search, list), package building, validation output,
colorization, and element introspection.

## Decision

The god class is **accepted** as the Thor command pattern. Thor commands
are defined as methods within a single class with `desc`/`long_desc`/`option`
declarations. Extracting display methods to a separate module would:

1. Separate `desc` declarations from method implementations — confusing
   for Thor users who expect `desc` immediately before `def`.
2. Risk breaking Thor's dispatch (Thor finds methods via
   `instance_method_defined?` on the class; included-module methods
   work but are non-standard for Thor commands).
3. Move code without concentrating complexity — the deletion test fails:
   the display methods and their helpers earn their keep in the command
   class because they ARE the command's interface.

The Package#build method was already split (TODO 27) into focused
sub-methods. The remaining methods (info, validate, extract, list,
search, tree) are each 30-60 lines — individual methods are well-sized;
only the file is large.
