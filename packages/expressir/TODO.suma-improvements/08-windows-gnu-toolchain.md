# 08 — Windows gnu toolchain for in-place ext builds

## Goal
Local windows source installs and windows CI in-place builds compile the
binding: rustup gnu target (`x86_64-pc-windows-gnu`) matching the mingw
ruby, so extconf's guard can be lifted there.

## Status
Superseded for CI by 01 (cross-gem containers carry coherent toolchains;
platform gems ship prebuilt). Kept for developers hacking on windows
checkouts directly.

## Acceptance
- a windows machine with the gnu target builds the ext via extconf
  without EXPRESSIR_CORE_FORCE
