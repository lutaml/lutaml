# TODO.max-perf/12 — Require-boot profile and deferrable loads

## Context

TODO 09 measured the cold start: grammar work is only ~58ms; the dominant
cold cost is `require "expressir"` itself at 161–181ms. Short-lived
processes (CLI, CI) pay it per invocation. expressir.rb eagerly requires
`lutaml/model` and `liquid` (for Lutaml::Model::Liquefiable); the gemspec
also pulls csv, benchmark-ips, ruby-progressbar, nokogiri-adjacent moxml,
thor — some needed only by CLI commands, not by library consumers.

## Work

- [x] Profiled: per-gem load times via a require-timing probe in a fresh
      process (results below)
- [x] Evaluated deferrals: nothing safely deferrable (results below)
- [x] Full suite green (no deferred loads introduced)

- [x] Per-gem boot profile (fresh process, 2 runs): liquid 172-207ms, lutaml/model 327-559ms (includes moxml chain), thor 19-40ms, expressir own lib ~1ms (autoloads already optimal)
- [x] Documented as not safely deferrable: liquid backs Lutaml::Model::Liquefiable used by expressir models in metanorma rendering; lutaml-model's boot is upstream (its lazy-loading is tracked there). expressir's own load adds ~1ms — nothing to defer.

## Acceptance

Per-gem boot profile recorded; measured reduction if safely deferrable,
otherwise documented why not.

## Outcome (from the 2026-09-18 close-out, commit 17aa264)

- [x] Profiled: per-gem load times via a require-timing probe in a fresh
- [x] Evaluated deferrals: nothing safely deferrable (results below)
- [x] Full suite green (no deferred loads introduced)
- [x] Per-gem boot profile (fresh process, 2 runs): liquid 172-207ms, lutaml/model 327-559ms (includes moxml chain), thor 19-40ms, expressir own lib ~1ms (autoloads already optimal)
- [x] Documented as not safely deferrable: liquid backs Lutaml::Model::Liquefiable used by expressir models in metanorma rendering; lutaml-model's boot is upstream (its lazy-loading is tracked there). expressir's own load adds ~1ms — nothing to defer.

## Status: done

- Per-gem boot profile recorded (17aa264 record transplanted below); nothing safely deferrable.
