# B3 Benchmark Results

Benchmarks comparing B3 (pure Elixir) against the `blake3` hex package (Rust NIF binding).

**Environment:** Elixir 1.19.5, OTP 28, Apple M1 Max, macOS, JIT enabled.

## The starting point

The original implementation was a faithful line-by-line port of the Rust reference implementation. Idiomatic Rust patterns (mutable arrays, in-place indexing) became pathological Elixir (linked lists with `Enum.at`, `List.replace_at`).

### Speed (x times slower than Rust NIF)

| Input  | hash   | keyed_hash | derive_key |
|--------|--------|------------|------------|
| 64 B   | 92x    | 98x        | 133x       |
| 1 KB   | 256x   | 255x       | 252x       |
| 64 KB  | 547x   | 543x       | 537x       |
| 1 MB   | 657x   | 649x       | 656x       |

### Memory (x times more allocation than Rust NIF)

| Input  | hash         | keyed_hash   | derive_key   |
|--------|--------------|--------------|--------------|
| 64 B   | 771x         | 778x         | 1,556x       |
| 1 KB   | 12,130x      | 12,136x      | 12,913x      |
| 64 KB  | 822,988x     | 823,022x     | 823,762x     |
| 1 MB   | 13,180,157x  | 13,179,029x  | 13,180,779x  |

The Rust NIF allocates a constant ~72 bytes regardless of input size. B3 allocated **905 MB to hash 1 MB** — roughly 905 bytes of heap per byte of input.

## Round 1: Data structures and compression core

The first round targeted the fundamental data structure choices and the hot compression function. All changes are in the four internal modules; the public API is unchanged.

### What changed

1. **Lists to tuples.** All internal state vectors (compression state, chaining values, block words, IV) converted from lists to tuples. `elem/2` is O(1) vs `Enum.at/2` O(n). This was the single largest win.

2. **Fully inlined compression rounds.** The `g` function, `round` helper, `permute` function, `update_state` helper, and recursive `mix` loop were all eliminated. The 7 rounds of 8 g-calls became a single `mix/17` function with all 448 operations on bare variables, all permutation indices hardcoded. Zero heap allocations inside `mix`.

3. **`band` instead of `rem`.** `rem(x, 4_294_967_296)` replaced with `band(x, 0xFFFFFFFF)`. Single bitwise AND vs integer division.

4. **Direct params/flags dispatch.** Changed from map-construction + `Map.get` to pattern-matched function clauses returning module attributes.

5. **Fast binary conversions.** `words_from_le_bytes/2` gained fast-path clauses using binary pattern matching directly into 16-word and 8-word tuples.

6. **Single-shot output binary.** Output blocks built as one `<<w0::little-32, ...>>` literal from 16 tuple elements, replacing 16 sequential concatenations.

### Round 1 results (vs Rust NIF)

| Input  | hash   | keyed_hash | derive_key |
|--------|--------|------------|------------|
| 64 B   | 6x     | 6x         | 10x        |
| 1 KB   | 12x    | 12x        | 13x        |
| 64 KB  | 24x    | 24x        | 24x        |
| 1 MB   | 27x    | 27x        | 28x        |

Memory for 1 MB hash dropped from **905 MB to 17.68 MB** (51x reduction). Speed improved 24x for 1 MB inputs.

## Round 2: Eliminating layer overhead

With the compression core near-optimal, profiling showed the remaining overhead was in the layers above: `ChunkState.update` created ~49K intermediate struct copies and ~16K binary concatenations per MB, and `Hasher.update` created ~1K unnecessary struct copies per MB.

### What changed

1. **`compress_cv/5`** (blake3.ex) — New function returning only the 8-word chaining value (first 8 XOR'd elements), not the full 16-tuple. Saves 8 `bxor` ops and halves the return tuple size. Used in `ChunkState.update`, `Output.chaining_value`, and the new 32-byte fast path. ~17K calls/MB switched from 16-tuple to 8-tuple return.

2. **`mix/32` + `g` macro** (blake3.ex) — Changed from 17 args (16 state + block tuple) to 32 bare args. Replaced all 112 `elem(m, N)` calls with direct variable references. The 7 rounds of 8 G-calls were then refactored into a `defmacrop g/6` that expands at compile time to the 8 arithmetic/rotation operations, reducing the `mix` body from ~520 lines to ~60 while producing identical bytecode.

3. **Binary-accepting function heads** (blake3.ex) — Both `compress/5` and `compress_cv/5` gained heads that pattern-match a 64-byte binary directly into 16 little-endian 32-bit words, eliminating the `words_from_le_bytes` conversion step for full blocks. ~15K calls/MB skip tuple construction.

4. **`compress_blocks` tight inner loop** (chunk_state.ex) — Replaced the recursive per-block `update/2` (3 struct copies + binary concat per block) with a tight loop on bare values. The key invariant: never compress the last block, leaving it buffered for `chunk_end` flag handling. **This was the most impactful Round 2 change**, eliminating ~48K struct copies and ~16K binary concats per MB.

5. **`merge_cv_stack` pure function** (hasher.ex) — Extracted the cv_stack merge loop from the hasher struct. Returns a new cv_stack list without touching the hasher. Combined with batching all struct updates into single `%{hasher | ...}` expressions. Replaced `Map.get(hasher.chunk_state, :chunk_counter)` with direct field access. Refactored `root_output` similarly.

6. **32-byte output fast path** (output.ex) — For the default (and most common) 32-byte output, uses `compress_cv` (8-tuple) instead of `compress` (16-tuple) and builds exactly 32 bytes instead of 64. One call per hash.

### Round 2 results (vs Rust NIF)

| Input  | hash   | keyed_hash | derive_key |
|--------|--------|------------|------------|
| 64 B   | 5x     | 4x         | 7x         |
| 1 KB   | 10x    | 9x         | 9x         |
| 64 KB  | 17x    | 17x        | 17x        |
| 1 MB   | 18x    | 18x        | 18x        |

Memory for 1 MB hash dropped from **17.68 MB to 6.69 MB** (2.6x further reduction).

## Bottom line

### Overall speed improvement (original B3 vs final B3)

| Input  | hash  | keyed_hash | derive_key |
|--------|-------|------------|------------|
| 64 B   | 19x   | 22x        | 19x        |
| 1 KB   | 26x   | 30x        | 28x        |
| 64 KB  | 32x   | 31x        | 31x        |
| 1 MB   | 36x   | 36x        | 36x        |

### Overall memory reduction (original B3 vs final B3)

| Input  | hash  | keyed_hash | derive_key |
|--------|-------|------------|------------|
| 64 B   | 35x   | 33x        | 33x        |
| 1 KB   | 136x  | 133x       | 113x       |
| 64 KB  | 135x  | 135x       | 134x       |
| 1 MB   | 135x  | 135x       | 135x       |

### Absolute numbers for hash mode

| Input  | Original     | After Round 1 | After Round 2 | Rust NIF   |
|--------|-------------|---------------|---------------|------------|
| 64 B   | 22.87 μs    | 1.47 μs       | 1.18 μs       | 0.24 μs    |
| 1 KB   | 364.43 μs   | 16.94 μs      | 14.01 μs      | 1.42 μs    |
| 64 KB  | 26.32 ms    | 1.15 ms       | 0.83 ms       | 0.048 ms   |
| 1 MB   | 504.73 ms   | 20.92 ms      | 14.04 ms      | 0.77 ms    |

### Memory for hash mode

| Input  | Original     | After Round 1 | After Round 2 |
|--------|-------------|---------------|---------------|
| 64 B   | 54.23 KB    | 1.72 KB       | 1.55 KB       |
| 1 KB   | 852.91 KB   | 17.19 KB      | 6.25 KB       |
| 64 KB  | 56.51 MB    | 1.11 MB       | 427.91 KB     |
| 1 MB   | 905.01 MB   | 17.68 MB      | 6.69 MB       |

### Where the wins came from

**Round 1 dominated speed** (24x of the total 36x for 1 MB). The list-to-tuple conversion and fully inlined `mix` function eliminated the catastrophic O(n) access and allocation patterns in the compression hot path.

**Round 2 dominated memory** at scale. The tight `compress_blocks` loop was the standout change: eliminating ~48K struct copies and ~16K binary concatenations per MB cut memory from 17.68 MB to 6.69 MB (62%) while also improving speed 1.5x at 1 MB.

The remaining ~18x speed gap vs the Rust NIF is the inherent cost of pure Elixir — immutable data structures, BEAM integer arithmetic, and functional recursion vs native SIMD-optimised C/Rust with in-place mutation. The memory gap (6.69 MB vs 72 bytes for 1 MB) reflects that every intermediate value in the BEAM is a heap-allocated term, while Rust operates on stack registers.
