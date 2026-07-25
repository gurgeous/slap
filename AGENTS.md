# Style

1. Keep code/docs/output simple and concise.
2. Comment major methods and tricky code.
3. Put only trivial one-liners under `# one-liners`.
4. Prefer readers over ivars except for assignment or Spinel type hints.
5. Prefer `each`/ranges over `while`; counters are `idx`.
6. Treat String as immutable: use `StringIO buf`, arrays + `join`, substitution, or interpolation. Never add frozen-string comments.
7. Prefer truthy checks over `nil?` when `false` is not distinct.
8. Do not change `.rubocop.yml` without asking.

# Tests

1. Run `just test` after every change.
2. Announce Spinel workaround/type-sensitive changes before testing.

# Spinel

1. Mark concessions with `# SPINEL WORKAROUND:` and cite `spinel_N.rb`.
2. Keep only repros proven by `spinel -o build/crash-N spinel_N.rb` and, if built, `build/crash-N`.
3. Headers stay current: bug, bad line if UNREDUCED, Ruby result, Spinel result.
4. Repros should become minimal, standalone, generic, and stdlib-only as time permits.
5. Repros prepared for reduction include `# reduce:freeze (do not modify anything below this line)`.
6. Runtime/wrong-output repros put the freeze marker directly above `raise "FAIL" if/unless ...`.
7. Compile-failure repros do not need a terminal assertion; put the freeze marker after the code.
8. Preserve reported C warnings during reduction.
