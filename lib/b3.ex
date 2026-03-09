defmodule B3 do
  @moduledoc """
  ![B3](https://raw.githubusercontent.com/aaronrussell/b3/main/media/poster.webp)

  ![License](https://img.shields.io/github/license/aaronrussell/b3?color=informational)

  B3 is a pure Elixir implementation of [BLAKE3](https://blake3.io), a modern
  cryptographic hash function.

  As well as regular hash, B3 is a PRF, MAC, KDF, and XOF. That's a lot of
  acronyms!

  B3 is a pure Elixir port of the BLAKE3 [reference implementation](https://github.com/BLAKE3-team/BLAKE3/blob/master/reference_impl/reference_impl.rs).
  Zero dependencies will make compilation and deployments simple, but if its
  performance you're after, you may want to check out the [blake3 package](https://github.com/Thomas-Jean/blake3)
  which uses Rustler to bind to the Rust BLAKE3 implementation.
  """
  alias B3.Hasher

  @doc """
  Returns a hash of the given message.

  ## Accepted options

  - `:length` - length of digest (default: 32)
  - `:encoding` - encode digest as (`:hex` or `:base64`)

  ## Example

      iex> B3.hash("test", encoding: :hex)
      "4878ca0425c739fa427f7eda20fe845f6b2e46ba5fe2a14df5b1e32f50603215"
  """
  @spec hash(binary(), keyword()) :: binary()
  def hash(message, opts \\ []) when is_binary(message),
    do: Hasher.new(:hash) |> digest(message, opts)

  @doc """
  Returns a keyed hash of the given message. Key must be 32 bytes.

  This mode removes the need for a seperate HMAC function.

  ## Accepted options

  - `:length` - length of digest (default: 32)
  - `:encoding` - encode digest as (`:hex` or `:base64`)

  ## Example

      iex> B3.keyed_hash("test", "testkeytestkeytestkeytestkeytest", encoding: :hex)
      "8bacb5b968184e269491c5022ec75d6b599ecf210ee3bb3a5208c1376f919202"
  """
  @spec keyed_hash(binary(), binary(), keyword()) :: binary()
  def keyed_hash(message, key, opts \\ [])
      when is_binary(message) and
             is_binary(key) and
             byte_size(key) == 32,
      do: Hasher.new(:keyed_hash, key) |> digest(message, opts)

  @doc """
  Derives a key from the given key material and context string.

  The context string should be globally unique and application specific.

  ## Accepted options

  - `:length` - length of key (default: 32)
  - `:encoding` - encode key as (`:hex` or `:base64`)

  ## Example

      iex> B3.derive_key("test", "[Test app] 1 Oct 2022 - Test keys", encoding: :hex)
      "79bb09c3d5f99890ef4a24316036dd7707e9c0e9d3315de168248e666639438d"
  """
  @spec derive_key(binary(), String.t(), keyword()) :: binary()
  def derive_key(material, context, opts \\ [])
      when is_binary(material) and
             is_binary(context),
      do: Hasher.new(:derive_key, context) |> digest(material, opts)

  # Uses the Hasher to calculate the digest of the given message
  defp digest(%Hasher{} = hasher, message, opts) do
    length = Keyword.get(opts, :length, 32)
    encoding = Keyword.get(opts, :encoding)

    hasher
    |> Hasher.update(message)
    |> Hasher.finalize(length)
    |> encode(encoding)
  end

  # Encodes the data has hex or base64
  defp encode(data, :base16), do: Base.encode16(data)
  defp encode(data, :base64), do: Base.encode64(data)
  defp encode(data, :hex), do: Base.encode16(data, case: :lower)
  defp encode(data, _), do: data
end
