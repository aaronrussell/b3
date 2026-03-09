defmodule B3.ChunkState do
  @moduledoc false

  import Bitwise
  alias B3.{Blake3, Output}

  defstruct [:chaining_value, :chunk_counter, :block, :blocks_compressed, :flags]

  @type t() :: %__MODULE__{
          chaining_value: list(integer()),
          chunk_counter: integer(),
          block: binary(),
          blocks_compressed: integer(),
          flags: integer()
        }

  @spec new(list(integer()), integer(), integer()) :: t()
  def new(key_words, chunk_counter, flags)
      when is_list(key_words) and
             is_integer(chunk_counter) and
             is_integer(flags) do
    struct(__MODULE__,
      chaining_value: key_words,
      chunk_counter: chunk_counter,
      # [0; BLOCK_LEN],
      block: "",
      blocks_compressed: 0,
      flags: flags
    )
  end

  @spec len(t()) :: integer()
  def len(%__MODULE__{blocks_compressed: blocks, block: block}),
    do: Blake3.params(:block_len) * blocks + byte_size(block)

  @spec update(t(), binary()) :: t()
  def update(%__MODULE__{} = state, ""), do: state

  def update(%__MODULE__{} = state, input) when is_binary(input) do
    state =
      case byte_size(state.block) == Blake3.params(:block_len) do
        true ->
          chaining_value =
            Blake3.compress(
              state.chaining_value,
              Blake3.words_from_le_bytes(state.block, 16),
              state.chunk_counter,
              Blake3.params(:block_len),
              state.flags ||| start_flag(state)
            )
            |> Enum.take(8)

          state
          |> Map.put(:chaining_value, chaining_value)
          |> Map.update!(:blocks_compressed, &(&1 + 1))
          |> Map.put(:block, "")

        false ->
          state
      end

    want = Blake3.params(:block_len) - byte_size(state.block)
    take = min(want, byte_size(input))
    <<input::binary-size(take), rest::binary>> = input

    state
    |> Map.update!(:block, &(&1 <> input))
    |> update(rest)
  end

  @spec output(t()) :: Output.t()
  def output(%__MODULE__{} = state) do
    %Output{
      input_chaining_value: state.chaining_value,
      block_words: Blake3.words_from_le_bytes(state.block, 16),
      counter: state.chunk_counter,
      block_len: byte_size(state.block),
      flags: state.flags ||| start_flag(state) ||| Blake3.flags(:chunk_end)
    }
  end

  defp start_flag(%__MODULE__{blocks_compressed: 0}), do: Blake3.flags(:chunk_start)
  defp start_flag(%__MODULE__{}), do: 0
end
