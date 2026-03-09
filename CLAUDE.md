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

The `blake3` hex package (Rust NIF binding) is a dev dependency used only for comparison validation in `scripts/`.

## Code Conventions

- Heavy use of `import Bitwise` for 32-bit arithmetic throughout the algorithm modules
- All internal modules use structs to carry state
- Output encoding options: raw binary (default), `:hex`, `:base16`, `:base64`
- Elixir >= 1.12 compatibility required
