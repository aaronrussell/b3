defmodule B3.Blake3 do
  # BLAKE3 algorithm module.
  @moduledoc false

  import Bitwise

  @out_len 32
  @key_len 32
  @block_len 64
  @chunk_len 1024

  @chunk_start 1 <<< 0
  @chunk_end 1 <<< 1
  @parent 1 <<< 2
  @root 1 <<< 3
  @keyed_hash 1 <<< 4
  @derive_key_context 1 <<< 5
  @derive_key_material 1 <<< 6

  @iv [
    0x6A09E667,
    0xBB67AE85,
    0x3C6EF372,
    0xA54FF53A,
    0x510E527F,
    0x9B05688C,
    0x1F83D9AB,
    0x5BE0CD19
  ]

  @typedoc "Initialization vector"
  @type iv() :: list(integer())

  @typedoc "BLAKE3 params"
  @type params() :: %{
          out_len: integer(),
          key_len: integer(),
          block_len: integer(),
          chunk_len: integer()
        }

  @typedoc "BLAKE3 flags"
  @type flags() :: %{
          chunk_start: integer(),
          chunk_end: integer(),
          parent: integer(),
          root: integer(),
          keyed_hash: integer(),
          derive_key_context: integer(),
          derive_key_material: integer()
        }

  @max_u32 4_294_967_296
  @msg_permutation [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]

  @doc """
  Returns the BLAKE3 initialization vector.
  """
  @spec iv() :: iv()
  def iv(), do: @iv

  @doc """
  Returns the BLAKE3 params.
  """
  @spec params() :: params()
  def params() do
    %{
      out_len: @out_len,
      key_len: @key_len,
      block_len: @block_len,
      chunk_len: @chunk_len
    }
  end

  @doc """
  Returns the BLAKE3 param for the given key.
  """
  @spec params(atom()) :: integer()
  def params(key), do: Map.get(params(), key)

  @doc """
  Returns the BLAKE3 flags.
  """
  @spec flags() :: flags()
  def flags() do
    %{
      chunk_start: @chunk_start,
      chunk_end: @chunk_end,
      parent: @parent,
      root: @root,
      keyed_hash: @keyed_hash,
      derive_key_context: @derive_key_context,
      derive_key_material: @derive_key_material
    }
  end

  @doc """
  Returns the BLAKE3 flag for the given key.
  """
  @spec flags(atom()) :: integer()
  def flags(key), do: Map.get(flags(), key)

  @doc """
  Takes a 128-byte chunk and mixes it into the chainign value.
  """
  @spec compress(list(integer()), list(integer()), integer(), integer(), integer()) ::
          list(integer())
  def compress(chaining_value, block_words, counter, block_len, flags) do
    state = [
      Enum.at(chaining_value, 0),
      Enum.at(chaining_value, 1),
      Enum.at(chaining_value, 2),
      Enum.at(chaining_value, 3),
      Enum.at(chaining_value, 4),
      Enum.at(chaining_value, 5),
      Enum.at(chaining_value, 6),
      Enum.at(chaining_value, 7),
      Enum.at(@iv, 0),
      Enum.at(@iv, 1),
      Enum.at(@iv, 2),
      Enum.at(@iv, 3),
      counter,
      counter >>> 32,
      block_len,
      flags
    ]

    Enum.reduce(0..7, mix(state, block_words), fn i, state ->
      state
      |> List.update_at(i, &bxor(&1, Enum.at(state, i + 8)))
      |> List.update_at(i + 8, &bxor(&1, Enum.at(chaining_value, i)))
    end)
  end

  @doc """
  Converts a binary string into a list of integers.
  """
  @spec words_from_le_bytes(binary(), integer()) :: list(integer())
  def words_from_le_bytes(bytes, len \\ 16) when len * 4 >= byte_size(bytes) do
    bytes
    |> words_from_le_bytes(len, [])
    |> Enum.reverse()
  end

  defp words_from_le_bytes("", len, words)
       when length(words) == len,
       do: words

  defp words_from_le_bytes("", len, words),
    do: words_from_le_bytes("", len, [0 | words])

  defp words_from_le_bytes(bytes, len, words) when byte_size(bytes) < 4 do
    (bytes <> :binary.copy(<<0>>, 4 - byte_size(bytes)))
    |> words_from_le_bytes(len, words)
  end

  defp words_from_le_bytes(<<word::little-32, bytes::binary>>, len, words),
    do: words_from_le_bytes(bytes, len, [word | words])

  # Mixes the state over 7 rounds
  @spec mix(list(integer()), list(integer())) :: list(integer())
  defp mix(state, block, n \\ 0)
  defp mix(state, _block, 7), do: state

  defp mix(state, block, n) do
    state
    |> round(block)
    |> mix(permute(block), n + 1)
  end

  # A single mix round
  @spec round(list(integer()), list(integer())) :: list(integer())
  defp round(state, block) do
    state
    # mix cols
    |> g([0, 4, 8, 12], Enum.at(block, 0), Enum.at(block, 1))
    |> g([1, 5, 9, 13], Enum.at(block, 2), Enum.at(block, 3))
    |> g([2, 6, 10, 14], Enum.at(block, 4), Enum.at(block, 5))
    |> g([3, 7, 11, 15], Enum.at(block, 6), Enum.at(block, 7))
    # mix diags
    |> g([0, 5, 10, 15], Enum.at(block, 8), Enum.at(block, 9))
    |> g([1, 6, 11, 12], Enum.at(block, 10), Enum.at(block, 11))
    |> g([2, 7, 8, 13], Enum.at(block, 12), Enum.at(block, 13))
    |> g([3, 4, 9, 14], Enum.at(block, 14), Enum.at(block, 15))
  end

  # The mixing function, G, which mixes either a column or a diagonal
  @spec g(list(integer()), list(integer()), integer(), integer()) :: list(integer())
  defp g(state, idxs, x, y) do
    [a, b, c, d] = Enum.map(idxs, &Enum.at(state, &1))

    a = rem(a + b + x, @max_u32)
    d = rotr(bxor(d, a), 16)
    c = rem(c + d, @max_u32)
    b = rotr(bxor(b, c), 12)
    a = rem(a + b + y, @max_u32)
    d = rotr(bxor(d, a), 8)
    c = rem(c + d, @max_u32)
    b = rotr(bxor(b, c), 7)

    update_state(state, idxs, [a, b, c, d])
  end

  @spec permute(list(integer())) :: list(integer())
  defp permute(block) do
    for i <- 0..15 do
      Enum.at(block, Enum.at(@msg_permutation, i))
    end
  end

  @spec rotr(integer(), integer()) :: integer()
  defp rotr(x, n) do
    (x >>> n)
    |> bxor(x <<< (32 - n))
    |> rem(@max_u32)
  end

  @spec update_state(list(integer()), list(integer()), list(integer())) :: list(integer())
  defp update_state(state, [], []), do: state

  defp update_state(state, [i | idxs], [v | vals]) do
    state
    |> List.replace_at(i, v)
    |> update_state(idxs, vals)
  end
end
