# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

B3 is a pure Elixir implementation of the BLAKE3 cryptographic hash function, ported from the official Rust reference implementation. It has zero runtime dependencies.

## Common Commands

- `mix deps.get` — fetch dependencies
- `mix test` — run the full test suite
- `mix test path/to/file.exs` — run tests in a specific file
- `mix test path/to/file.exs:84` — run a specific test by line number
- `mix format` — format code
- `mix format --check-formatted` — check formatting without fixing
- `mix docs` — generate documentation

## Architecture

The library is organized into four internal modules beneath the public `B3` API:

```
B3 (lib/b3.ex)              — Public API: hash/2, keyed_hash/3, derive_key/3
├── B3.Hasher                — State machine: new → update (incremental) → finalize
├── B3.ChunkState            — Buffers input into 64-byte blocks within 1024-byte chunks
├── B3.Blake3                — Core compression function, constants, IV, flag definitions
└── B3.Output                — Generates variable-length output from compression state
```

**Data flow**: `B3` creates a `Hasher` → `Hasher.update/2` feeds bytes into `ChunkState` → `ChunkState` calls `Blake3.compress/5` per block → `Hasher.finalize/2` produces an `Output` struct → `Output.root_output_bytes/2` generates the final digest.

**Tree hashing**: The `Hasher` maintains a `cv_stack` (chaining value stack) that merges completed chunks in a binary tree structure, enabling the Merkle tree construction that BLAKE3 uses.

**Modes**: Three operational modes controlled by flag constants in `Blake3` — standard hash, keyed hash (32-byte key), and key derivation (context string).

## Testing

Tests in `test/b3_test.exs` are generated from `test/test_vectors.json` (official BLAKE3 test vectors). Each vector is tested across all three modes (hash, keyed_hash, derive_key) verifying both default 32-byte and extended 131-byte output lengths.

## Performance Architecture

The codebase has been heavily optimised across two rounds (see `context/optimisations.md` for full details and benchmarks). Key design decisions that must be preserved:

- **Tuples, not lists** for all fixed-size state vectors (compression state, chaining values, block words, IV). `elem/2` is O(1); switching back to lists would be catastrophic.
- **`mix/32` with bare variables** — the compression core takes 32 individual args (16 state + 16 message words) to avoid tuple allocation inside the hot loop. The `g` macro (`defmacrop g/6`) expands at compile time to the 8 mixing operations per G-call, keeping the source compact (~60 lines) while producing fully inlined bytecode.
- **`compress_cv/5`** returns only the 8-word chaining value (not the full 16-tuple). Used everywhere except `root_output_bytes` which needs the full state.
- **Binary-accepting function heads** on `compress/5` and `compress_cv/5` pattern-match 64-byte binaries directly, skipping `words_from_le_bytes` for full blocks.
- **`compress_blocks/5`** in ChunkState is a tight recursive loop on bare values (cv, block_count, chunk_counter, flags, input). Never compresses the last block — it stays buffered for `chunk_end` flag handling.
- **`merge_cv_stack/5`** and `root_output/4` in Hasher are pure functions operating on bare values, not the hasher struct, to avoid intermediate struct copies.
- **32-byte output fast path** in Output uses `compress_cv` instead of full `compress`.

## Benchmarking

- `mix run bench/hash_bench.exs` — B3 vs Rust NIF (hash mode)
- `mix run bench/keyed_hash_bench.exs` — keyed hash mode
- `mix run bench/derive_key_bench.exs` — derive key mode
- Raw benchmark results are stored in `bench/` with date-prefixed filenames
- The `blake3` hex package (Rust NIF binding) is a dev dependency used for benchmark comparison and validation in `scripts/`

## Code Conventions

- Heavy use of `import Bitwise` for 32-bit arithmetic throughout the algorithm modules
- All internal modules use structs to carry state
- Module attributes (`@block_len`, `@chunk_start`, etc.) used for constants instead of function calls in hot paths
- Output encoding options: raw binary (default), `:hex`, `:base16`, `:base64`
- Elixir >= 1.12 compatibility required
