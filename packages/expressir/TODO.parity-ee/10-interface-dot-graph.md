# 10 — Interface dependency dot graph (kernel/dot-graph.lisp)

**Status: NOT STARTED**

## Goal

Emit GraphViz dot for schema interface dependencies exactly like eeng
(qualify.sh "Generate Dot File (interface)"), from our compiled
reference graph (already computes interface edges + closures over the
full SMRL).

## Notes

eeng's dot generation honors the concatenated mode (root-schema
subgraph); replicate node/edge/styling choices so WG12 visual
diffing stays stable. Trivial once 02 documents their exact output
shape — deliberately last in the queue.

## Acceptance

Byte-comparable dot output vs eeng for arm/mim of the golden modules.
