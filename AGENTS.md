# Style

1. Keep code/docs/output simple and concise.
2. Comment major methods and tricky code.
3. Put only trivial one-liners under `# one-liners`.
4. Prefer readers over ivars except for assignment or Spinel type hints.
5. Prefer `each`/ranges over `while`; counters are `idx`.
6. Treat String as immutable: use `StringIO buf`, arrays + `join`, substitution, or interpolation. Never add frozen-string comments.
7. Prefer truthy checks over `nil?` when `false` is not distinct.
8. Do not change `.rubocop.yml` without asking.
9. Keep PR/commit text succinct: one or two sentences tops. PR titles should be only a few words.

# Tests

1. Run `just test` after every change, except changes limited to `reduce`.
2. Announce Spinel workaround/type-sensitive changes before testing.
3. Normal `*_test.rb` files should end with `puts "ok"` by convention.
4. Use `just test-regen` only when intentionally updating snapshots; review generated `*.expected` files before committing them.
5. Tests may use stdout/stderr when that behavior matters, but prefer `assert_equal`/`assert_raises` for ordinary library assertions.

# Spinel

1. Mark concessions with `# SPINEL WORKAROUND:` and cite `spinel_N.rb`.
2. Keep only repros proven by `spinel -o build/crash-N spinel_N.rb` and, if built, `build/crash-N`.
3. Headers stay current: bug, bad line if UNREDUCED, Ruby result, Spinel result.
4. Never reuse a Spinel bug number; use the next number for a distinct or re-expanded issue.
5. Repros should become minimal, standalone, generic, and stdlib-only as time permits.
6. Repros must not require `slap` or use `require_relative "slap"`; inline the needed code.
7. Use `# keep` to protect causal code from reduction. Inline `# keep` preserves that line; a standalone `# keep` preserves the following tail, including the assertion.
8. Runtime/wrong-output repros put a standalone `# keep` directly above `raise "FAIL" if/unless ...`.
9. Compile-failure repros do not need a terminal assertion; put a standalone `# keep` after the code.
10. Preserve reported C warnings during reduction.
11. Before repro/reduction, record Ruby/Spinel commands, statuses, and full Spinel stderr; candidates must match stderr byte-for-byte.
12. Inline dependencies one at a time, checking the baseline each time. Stop after a complete pass gains under 50 bytes or 1%, then recheck the final artifact.
