# Express Engine fixtures — provenance

Imported verbatim (2026-09-21) from Express Engine "The Next
Generation" at `~/src/external/exp-engine-engine` (upstream:
SourceForge `expengine`, Craig Lanning). License: MIT-style, per the
header in each Lisp source file ("Copyright (c) 2009 Craig Lanning",
permission notice included) — recheck the exact upstream revision hash
before redistributing beyond this repository.

Contents:

- `scripts/` — the 14 release-suite drivers (qualification loops,
  pretty matrix over ap209/ap210/ap242, XML/HTM chains, corpus scans).
  They reference eeng CLI binaries and remote STEPmod paths; kept as
  the authoritative definition of the operation matrix for
  TODO.parity-ee/11's RSpec translations.
- `issues/` — the bug corpus. bug39 carries the old-vs-new **shtolo**
  outputs (and stepcode exppp as a third opinion) that anchor the
  formatter parity specs.
- `grammar/` — BNF grammars (ISO 10303-11:2004, -14, -21:1994,
  -21:2002, xml) and the XML DTDs eeng emits against.
- `notes/` — `00check.txt` (check.lisp design notes), `qualify.txt`,
  `interfaces.txt`.
- `qualify-mod.txt`, `qualify-res.txt`, `resources.lst`,
  `modules.lst` — their corpus lists (names match the SRL manifests).

NOT imported (binaries/large references, read them in the eeng
checkout): `docs/*.pdf|odt` — including
`shtolo_converting_STEP_short_listings_to_annotated_listings_libes.pdf`,
the SHTOLO paper, and the interface-notes documents.
