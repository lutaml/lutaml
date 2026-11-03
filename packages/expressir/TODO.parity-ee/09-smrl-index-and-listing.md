# 09 — SMRL index XML + declaration listing (wo-list, wo-smrl-xml)

**Status: NOT STARTED**

## Goal

The SRL publication byproducts eeng generates: declaration listings
(`-list.txt`) and the SMRL index XML for longform/concatenated files
(`<concatenated_express_file_content_list>`), emitted from the same
model that powers 04/05.

## Sources

`plugins/p11/wo-list.lisp`, `wo-smrl-xml.lisp` (element names:
concatenated_express_file_content_list, per-schema content entries),
top-level.lisp:748-793 (when the index is generated: XML output +
longform/concatenated modes).

## Acceptance

Index/list output for the 03 golden set structurally identical
(element-for-element) to eeng's; wired into the same CLI as 04.
