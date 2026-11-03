  # --- operator terminals (cstr(lit).as(name); trivia rides the skip) ---
  op_asterisk = ("*" as str) as op_asterisk
  op_colon = (":" as str) as op_colon
  op_colon_equals_colon = (":=:" as str) as op_colon_equals_colon
  op_colon_less_greater_colon = (":<>:" as str) as op_colon_less_greater_colon
  op_comma = ("," as str) as op_comma
  op_decl = (":=" as str) as op_decl
  op_delim = (";" as str) as op_delim
  op_double_asterisk = ("**" as str) as op_double_asterisk
  op_double_backslash = (%x5C as str) as op_double_backslash
  op_double_pipe = ("||" as str) as op_double_pipe
  op_equals = ("=" as str) as op_equals
  op_greater_equal = (">=" as str) as op_greater_equal
  op_greater_than = (">" as str) as op_greater_than
  op_leftbracket = ("[" as str) as op_leftbracket
  op_left_curly_brace = ("{" as str) as op_left_curly_brace
  op_leftparen = ("(" as str) as op_leftparen
  op_less_equal = ("<=" as str) as op_less_equal
  op_less_greater = ("<>" as str) as op_less_greater
  op_less_than = ("<" as str) as op_less_than
  op_minus = ("-" as str) as op_minus
  op_period = ("." as str) as op_period
  op_pipe = ("|" as str) as op_pipe
  op_plus = ("+" as str) as op_plus
  op_query_begin = ("<*" as str) as op_query_begin
  op_query_end = ("*>" as str) as op_query_end
  op_question_mark = ("?" as str) as op_question_mark
  op_rightbracket = ("]" as str) as op_rightbracket
  op_right_curly_brace = ("}" as str) as op_right_curly_brace
  op_rightparen = (")" as str) as op_rightparen
  op_slash = ("/" as str) as op_slash
  # ordered-union the DSL builds for the operators where alternatives
  # appear: longest-first at every alternation site that references them
  # (op_colon_equals_colon / op_colon etc.) — the sites keep the DSL order.
