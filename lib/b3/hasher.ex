defmodule B3.Hasher do
  @moduledoc false

  import Bitwise
  alias B3.{Blake3, ChunkState, Output}

  defstruct [:chunk_state, :key_words, :cv_stack, :flags]

  @chunk_len 1024
  @block_len 64
  @parent 1 <<< 2

  @type t() :: %__MODULE__{
          chunk_state: ChunkState.t(),
          key_words: tuple(),
          cv_stack: list(tuple()),
          flags: integer()
        }

  @type mode() :: :hash | :keyed_hash | :derive_key

  @spec new(mode()) :: t()
  def new(:hash), do: init(Blake3.iv(), 0)

  @spec new(mode(), binary()) :: t()
  def new(:keyed_hash, key) when is_binary(key) and byte_size(key) == 32 do
    key
    |> Blake3.words_from_le_bytes(8)
    |> init(Blake3.flags(:keyed_hash))
  end

  def new(:derive_key, context) when is_binary(context) do
    init(Blake3.iv(), Blake3.flags(:derive_key_context))
    |> update(context)
    |> finalize(32)
    |> Blake3.words_from_le_bytes(8)
    |> init(Blake3.flags(:derive_key_material))
  end

  @spec update(t(), binary()) :: t()
  def update(%__MODULE__{} = hasher, ""), do: hasher

  def update(%__MODULE__{} = hasher, input) when is_binary(input) do
    hasher =
      case ChunkState.len(hasher.chunk_state) == @chunk_len do
        true ->
          chunk_cv =
            hasher.chunk_state
            |> ChunkState.output()
            |> Output.chaining_value()

          total_chunks = hasher.chunk_state.chunk_counter + 1

          cv_stack =
            merge_cv_stack(
              hasher.cv_stack,
              chunk_cv,
              total_chunks,
              hasher.key_words,
              hasher.flags
            )

          %{
            hasher
            | cv_stack: cv_stack,
              chunk_state: ChunkState.new(hasher.key_words, total_chunks, hasher.flags)
          }

        false ->
          hasher
      end

    want = @chunk_len - ChunkState.len(hasher.chunk_state)
    take = min(want, byte_size(input))
    <<input::binary-size(take), rest::binary>> = input

    %{hasher | chunk_state: ChunkState.update(hasher.chunk_state, input)}
    |> update(rest)
  end

  @spec finalize(t(), integer()) :: binary()
  def finalize(%__MODULE__{} = hasher, bytes) when is_integer(bytes) do
    output = ChunkState.output(hasher.chunk_state)

    root_output(hasher.cv_stack, output, hasher.key_words, hasher.flags)
    |> Output.root_output_bytes(bytes)
  end

  defp init(key_words, flags) when is_tuple(key_words) and is_integer(flags) do
    %__MODULE__{
      chunk_state: ChunkState.new(key_words, 0, flags),
      key_words: key_words,
      cv_stack: [],
      flags: flags
    }
  end

  # Pure function: merges cv_stack without touching hasher struct
  defp merge_cv_stack(cv_stack, new_cv, total_chunks, key_words, flags) do
    case (total_chunks &&& 1) == 0 do
      true ->
        [top_cv | rest] = cv_stack

        new_cv =
          parent_output(top_cv, new_cv, key_words, flags)
          |> Output.chaining_value()

        merge_cv_stack(rest, new_cv, total_chunks >>> 1, key_words, flags)

      false ->
        [new_cv | cv_stack]
    end
  end

  defp parent_output(left_child_cv, right_child_cv, key_words, flags) do
    {l0, l1, l2, l3, l4, l5, l6, l7} = left_child_cv
    {r0, r1, r2, r3, r4, r5, r6, r7} = right_child_cv

    %Output{
      input_chaining_value: key_words,
      block_words: {l0, l1, l2, l3, l4, l5, l6, l7, r0, r1, r2, r3, r4, r5, r6, r7},
      counter: 0,
      block_len: @block_len,
      flags: @parent ||| flags
    }
  end

  # Pure function: walks cv_stack without struct updates
  defp root_output([], %Output{} = output, _key_words, _flags), do: output

  defp root_output([top_cv | cv_stack], %Output{} = output, key_words, flags) do
    output =
      parent_output(
        top_cv,
        Output.chaining_value(output),
        key_words,
        flags
      )

    root_output(cv_stack, output, key_words, flags)
  end
end
