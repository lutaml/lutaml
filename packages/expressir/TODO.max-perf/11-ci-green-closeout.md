# TODO.max-perf/11 — CI green close-out

## Context

TODO 01's final checkbox. Main carries the Windows fork guard (#353), the
engine-selection guard pinning :standard adapters on `Gem.win_platform?`
(#354), and the builder memoization (#355). yeptris mingw remains broken
upstream (leptris/yeptris#318); the guard must keep it unloaded.

## Work

- [x] Confirmed locally via full `bundle exec rake` (CI-equivalent):
      1558 examples, 0 failures, rubocop clean across 325 files
- [x] If red: diagnose the failing job, fix in expressir if the defect is
      here, escalate upstream otherwise

- [x] Root causes of the red run on 35c1f62 found and fixed: (1) rubocop offenses in the committed benchmark harness + a directive typo in another session's remark perf spec — fixed; (2) sequential-path nil-pad parity bug in from_files — fixed with regression spec; (3) strict-mode spec unguarded on fork-less platforms — guarded; (4) yeptris still loading on Windows: root cause is lutaml-model#798 (configured adapter fell through to detection, loading yeptris before any expressir pin could apply) — fixed upstream + expressir spec_helper now pins json too, with a temporary require-spy proving zero yeptris loads in the suite

- [x] Landed on main via #357 (the #356 merge had gone to its stale base
      branch `feat/max-perf-todos`; cherry-picked 17aa264 onto main and
      re-landed as 0576a08)

## Acceptance

rake green on main; TODO 01's checkbox ticked.

## Status: done

- Landed via #357 (17aa264 re-landed as 0576a08 after the #356 stale-base detour); rake green on main.
