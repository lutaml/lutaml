  # --- literal terminals (hand-translated) ---
  digit = %x30-39
  digits = 1*%x30-39
  # One quantified class run (parsanol GH-69: a single Re consumes the
  # whole identifier in one step), guarded against every keyword.
  simpleId = (!kwAny ((%x41-5A / %x61-7A / "_") *(%x41-5A / %x61-7A / %x30-39 / "_")) as str) as simpleId
  simpleStringLiteral = ("'" (*(!"'" %x01-10FFFF)) "'") as simpleStringLiteral
  octet = (%x30-39 / %x41-46 / %x61-66) (%x30-39 / %x41-46 / %x61-66)
  encodedStringLiteral = ("'" octet octet octet octet "'") as encodedStringLiteral
