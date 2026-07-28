---
name: logical-reduction
description: Reduce bug repros manually with reasoned semantic cuts and verification after each change. Use when asked to reduce, simplify, minimize, or logically shrink a repro without automated reducers, especially compiler/runtime repros where preserving the same failure matters.
---

# Logical Reduction

Reduce by understanding the program, not by blind deletion. Make one semantic cut at a time, verify, then keep or revert.

## Invariant

The reduced program must reproduce the exact same failure as the baseline after every accepted cut.

Same failure means the same error class, crash kind, signal/status, failing phase, and meaningful stdout/stderr signature. A segfault must remain the same segfault. A runtime error must remain the same runtime error. A compile failure must remain the same compile failure. Wrong output must remain the same wrong output. If the program passes, fails earlier, fails later, crashes differently, changes from crash to exception, changes from runtime failure to compile failure, or changes meaningful diagnostics, the reduction failed and must be reverted.

Compare status code first, then compare stdout/stderr for the same thrust, not byte-identical text. Incidental content that a cut necessarily changes — line numbers, file paths, variable names/values in a message, timestamps — is expected to differ and does not invalidate the reduction. What must not change: the message's error class/kind, which phase it came from, and its meaningful shape (e.g. "undefined method `foo' for nil" staying that same method/class of error, not silently becoming empty output or a different exception entirely).

## Workflow

1. Record the baseline command, status, stdout, stderr, and failure signature.
2. Pick one hypothesis: a feature, type, branch, class, assertion group, or scenario to remove.
3. Rewrite all call sites first; delete support code only after usages are gone.
4. Verify with the same baseline commands.
5. Keep the cut only if Ruby still passes and the exact target failure is unchanged.
6. Revert immediately if the failure changes in any way, becomes a compile error, or passes.
7. Write every accepted cut back to the real repro file immediately, not just a scratch/build copy. Do this after each individual accepted cut, not batched at the end — the real file is the record of progress and must never fall behind a scratch copy, so work survives an interruption.
8. Commit no temporary artifacts unless asked.

## Good Cuts

- Remove all assertions, or one assertion group at a time.
- Remove early exits: help, version, naked mode, injected exits.
- Remove builtins: auto help/version flags and builtin dispatch checks.
- Remove feature families: color, help rendering, word wrapping, separators, positionals.
- Remove one flag kind at a time: bool, int, float, string, symbol, path.
- Remove choices, defaults, required flags, negation, smashed flags, inline values.
- Remove modules/classes only after moving methods/constants or rewriting receivers.
- Replace rich objects with hashes/arrays/strings when type shape is not causal.
- Collapse repeated scenarios to the smallest set that still preserves the failure.
- Remove stdout/stderr writes only if stream behavior is not part of the failure.

## Rules

- Never let the verification harness itself change what code path runs. Redirecting stdout/stderr to a file changes `$stdout.tty?` from what it is in a real terminal, which can silently skip a branch (terminal-width detection, color auto-detection, `io/console`-dependent calls) that the removed code depended on. A cut that looks clean under piped-only verification can still break the program when actually run. Verify under the same conditions the file will really be invoked in — if that includes an interactive terminal, check under a real or emulated tty (e.g. `script -qec "ruby repro.rb" /dev/null`) too, not just piped.
- Never use an automated reducer unless the user explicitly asks.
- Do not create `*_reduce.*` files unless asked.
- Avoid naive deletion; keep code compiling and semantically equivalent for the tested path.
- Preserve platform details when the failure is platform-specific.
- Prefer temporary copies for probes when a cut is risky; apply only verified cuts to the real file.
- When in doubt, keep a smaller causal scenario over a larger incidental one.
- Do not accept a reduction because it still fails; accept only when it fails in the same way.

## Verification

Use the exact baseline commands. For a Spinel-style repro, verify at least:

```sh
ruby repro.rb > build/ruby.out 2> build/ruby.err
script -qec "ruby repro.rb" /dev/null > build/ruby.tty.log 2>&1  # catches tty-gated regressions piping hides
spinel -o build/crash repro.rb > build/compile.out 2> build/compile.err
build/crash > build/spinel.out 2> build/spinel.err
```

Compare status and stderr/stdout against the baseline. A different failure is not a valid reduction. If exact preservation cannot be checked in the current environment, stop or make only disposable candidate edits; do not apply them to the real repro.
