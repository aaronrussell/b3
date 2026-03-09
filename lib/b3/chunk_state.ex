defmodule B3.ChunkState do
  @moduledoc false

  import Bitwise
  alias B3.{Blake3, Output}

  defstruct [:chaining_value, :chunk_counter, :block, :blocks_compressed, :flags]

  @block_len 64
  @chunk_start 1

  @type t() :: %__MODULE__{
          chaining_value: tuple(),
          chunk_counter: integer(),
          block: binary(),
          blocks_compressed: integer(),
          flags: integer()
        }

  @spec new(tuple(), integer(), integer()) :: t()
  def new(key_words, chunk_counter, flags)
      when is_tuple(key_words) and
             is_integer(chunk_counter) and
             is_integer(flags) do
    struct(__MODULE__,
      chaining_value: key_words,
      chunk_counter: chunk_counter,
      block: "",
      blocks_compressed: 0,
      flags: flags
    )
  end

  @spec len(t()) :: integer()
  def len(%__MODULE__{blocks_compressed: blocks, block: block}),
    do: @block_len * blocks + byte_size(block)

  @spec update(t(), binary()) :: t()
  def update(%__MODULE__{} = state, ""), do: state

  # Non-empty block buffer: fill it, compress if full AND more data remains, then hand off
  def update(%__MODULE__{block: block} = state, input)
      when is_binary(input) and byte_size(block) > 0 do
    want = @block_len - byte_size(block)
    take = min(want, byte_size(input))
    <<chunk::binary-size(take), rest::binary>> = input
    filled = block <> chunk

    case byte_size(filled) == @block_len and byte_size(rest) > 0 do
      true ->
        # Compress the full block and continue with bare values
        block_flags =
          if state.blocks_compressed == 0, do: state.flags ||| @chunk_start, else: state.flags

        cv =
          Blake3.compress_cv(
            state.chaining_value,
            filled,
            state.chunk_counter,
            @block_len,
            block_flags
          )

        {cv, bc, remaining} =
          compress_blocks(cv, state.blocks_compressed + 1, state.chunk_counter, state.flags, rest)

        %{state | chaining_value: cv, blocks_compressed: bc, block: remaining}

      false ->
        %{state | block: filled}
    end
  end

  # Empty block buffer: straight to compress_blocks
  def update(%__MODULE__{block: ""} = state, input) when is_binary(input) do
    {cv, bc, remaining} =
      compress_blocks(
        state.chaining_value,
        state.blocks_compressed,
        state.chunk_counter,
        state.flags,
        input
      )

    %{state | chaining_value: cv, blocks_compressed: bc, block: remaining}
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

  # Tight inner loop: compress full 64-byte blocks without struct allocation.
  # Never compresses the last block — it stays buffered for chunk_end flag handling.
  defp compress_blocks(cv, bc, chunk_counter, flags, <<block::binary-64, rest::binary>>)
       when byte_size(rest) > 0 do
    block_flags = if bc == 0, do: flags ||| @chunk_start, else: flags
    cv = Blake3.compress_cv(cv, block, chunk_counter, @block_len, block_flags)
    compress_blocks(cv, bc + 1, chunk_counter, flags, rest)
  end

  defp compress_blocks(cv, bc, _chunk_counter, _flags, remaining) do
    {cv, bc, remaining}
  end

  defp start_flag(%__MODULE__{blocks_compressed: 0}), do: Blake3.flags(:chunk_start)
  defp start_flag(%__MODULE__{}), do: 0
end
