# `$stderr = $stdout` segfaults on the next GC cycle

# https://github.com/matz/spinel/issues/3410

**Spinel:** `0ccc3cebda09`

## Repro (`76_repro.rb`)

```ruby
$stderr = $stdout
GC.start
puts "still alive"
```

`ruby` passes. `spinel -o repro 76_repro.rb && ./repro` compiles clean, then segfaults (139) before printing anything.

## Root cause

`sp_io_stdout()`/`sp_io_stderr()` (`lib/sp_io.c:190-200`) return pointers to function-local **`static sp_File`** singletons in `.bss` — no `sp_gc_hdr` in front of them, unlike heap-allocated `sp_File`s (e.g. `File.open`). Normally harmless, since `$stdout`/`$stderr` reads just call these functions directly.

`$stderr = $stdout` stores that static pointer into `gv_stderr`, a real GC root that the generated globals-mark hook scans every cycle. On the next collection, `sp_gc_mark()` (`lib/sp_gc.c:133`) reads the tag byte at `obj[-1]` expecting a real header; over static `.bss` data it's garbage, doesn't match any skip tag, so the code fabricates a header at `obj - sizeof(sp_gc_hdr)` and jumps through its garbage `scan` pointer → SIGSEGV.

Confirmed with `SPINEL_GC_VERIFY=1`:

```
[phase=globals ctx=(nil)]
*** SPINEL_GC_VERIFY: collector reached a non-heap/corrupt object ***
  ->scan = 0x40000   ->size = 262144
```

`phase=globals` pins it to the `gv_stderr` mark.

## Suggested fix

Give the stdout/stderr/stdin singletons a real, one-time `sp_gc_hdr` with a no-op `scan` and a permanent skip tag (same trick as the existing "fd-buffer" string case, `#3151`) — or special-case these three pointers in `sp_gc_mark()` and skip them outright.
