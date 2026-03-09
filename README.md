# B3

![B3](https://raw.githubusercontent.com/aaronrussell/b3/main/media/poster.webp)

![Hex.pm](https://img.shields.io/hexpm/v/b3?color=informational)
![License](https://img.shields.io/github/license/aaronrusell/b3?color=informational)
![Build Status](https://img.shields.io/github/actions/workflow/status/aaronrusell/b3/elixir.yml?branch=main)

B3 is a pure Elixir implementation of [BLAKE3](https://blake3.io), a modern cryptographic hash function.

As well as regular hash, B3 is a PRF, MAC, KDF, and XOF. That's a lot of acronyms!

B3 is a pure Elixir port of the BLAKE3 [reference implementation](https://github.com/BLAKE3-team/BLAKE3/blob/master/reference_impl/reference_impl.rs). Zero dependencies will make compilation and deployments simple, but if its
performance you're after, you may want to check out the [blake3 package](https://github.com/Thomas-Jean/blake3) which uses Rustler to bind to the Rust BLAKE3 implementation.

## Installation

The package can be installed by adding `b3` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:b3, "~> 0.1"}
  ]
end
```

## Usage

The `B3` module provides three functions for all your hashing and key derivation needs:

- `B3.hash/2` - Returns a hash of the given message.
- `B3.keyed_hash/3` - Returns a keyed hash of the given message. Key must be 32 bytes.
- `B3.derive_key/3` - Derives a key from the given key material and context string.

All functions accept a keyword list of options:

- `:length` - length in bytes of the resulting digest (default 32)
- `:encoding` - optional encoding of the resulting digest (from `:base16`, `:base64` or `:hex`)

## Examples

```elixir
B3.hash("test", encoding: :hex)
"4878ca0425c739fa427f7eda20fe845f6b2e46ba5fe2a14df5b1e32f50603215"

B3.keyed_hash("test", "testkeytestkeytestkeytestkeytest", encoding: :hex)
"8bacb5b968184e269491c5022ec75d6b599ecf210ee3bb3a5208c1376f919202"

B3.derive_key("test", "[Test app] 1 Oct 2022 - Test keys", encoding: :hex)
"79bb09c3d5f99890ef4a24316036dd7707e9c0e9d3315de168248e666639438d"
```

## License

Eddy is open source and released under the [Apache-2 License](https://github.com/aaronrusell/b3/blob/main/LICENSE).

© Copyright 2023-2026 [Push Code Ltd](https://www.pushcode.com/).
