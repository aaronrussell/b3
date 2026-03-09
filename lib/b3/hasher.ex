defmodule B3.Hasher do
  @moduledoc false

  import Bitwise
  alias B3.{Blake3, ChunkState, Output}

  defstruct [:chunk_state, :key_words, :cv_stack, :flags]

  @type t() :: %__MODULE__{
          chunk_state: ChunkState.t(),
          key_words: list(integer()),
          cv_stack: list(list(integer())),
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
      case ChunkState.len(hasher.chunk_state) == Blake3.params(:chunk_len) do
        true ->
          chunk_cv =
            hasher.chunk_state
            |> ChunkState.output()
            |> Output.chaining_value()

          total_chunks = Map.get(hasher.chunk_state, :chunk_counter) + 1

          hasher
          |> add_chunk_chaining_value(chunk_cv, total_chunks)
          |> Map.put(:chunk_state, ChunkState.new(hasher.key_words, total_chunks, hasher.flags))

        false ->
          hasher
      end

    want = Blake3.params(:chunk_len) - ChunkState.len(hasher.chunk_state)
    take = min(want, byte_size(input))
    <<input::binary-size(take), rest::binary>> = input

    hasher
    |> Map.update!(:chunk_state, &ChunkState.update(&1, input))
    |> update(rest)
  end

  @spec finalize(t(), integer()) :: binary()
  def finalize(%__MODULE__{} = hasher, bytes) when is_integer(bytes) do
    output = ChunkState.output(hasher.chunk_state)

    hasher
    |> root_output(output)
    |> Output.root_output_bytes(bytes)
  end

  defp init(key_words, flags) when is_list(key_words) and is_integer(flags) do
    %__MODULE__{
      chunk_state: ChunkState.new(key_words, 0, flags),
      key_words: key_words,
      cv_stack: [],
      flags: flags
    }
  end

  defp add_chunk_chaining_value(%__MODULE__{} = hasher, new_cv, total_chunks)
       when is_list(new_cv) and is_integer(total_chunks) do
    case (total_chunks &&& 1) == 0 do
      true ->
        [top_cv | cv_stack] = hasher.cv_stack

        new_cv =
          parent_output(top_cv, new_cv, hasher.key_words, hasher.flags)
          |> Output.chaining_value()

        hasher
        |> Map.put(:cv_stack, cv_stack)
        |> add_chunk_chaining_value(new_cv, total_chunks >>> 1)

      false ->
        update_in(hasher.cv_stack, &[new_cv | &1])
    end
  end

  defp parent_output(left_child_cv, right_child_cv, key_words, flags) do
    block_words = left_child_cv ++ right_child_cv

    %Output{
      input_chaining_value: key_words,
      block_words: block_words,
      counter: 0,
      block_len: Blake3.params(:block_len),
      flags: Blake3.flags(:parent) ||| flags
    }
  end

  defp root_output(%__MODULE__{cv_stack: []}, %Output{} = output), do: output

  defp root_output(%__MODULE__{cv_stack: [top_cv | cv_stack]} = hasher, %Output{} = output) do
    output =
      parent_output(
        top_cv,
        Output.chaining_value(output),
        hasher.key_words,
        hasher.flags
      )

    hasher
    |> Map.put(:cv_stack, cv_stack)
    |> root_output(output)
  end
end
