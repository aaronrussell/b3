defmodule B3.Output do
  @moduledoc false
  import Bitwise
  alias B3.Blake3

  defstruct [:input_chaining_value, :block_words, :counter, :block_len, :flags]

  @type t() :: %__MODULE__{
          input_chaining_value: list(integer()),
          block_words: list(integer()),
          counter: integer(),
          block_len: integer(),
          flags: integer()
        }

  @root 1 <<< 3

  @spec chaining_value(t()) :: list(integer())
  def chaining_value(%__MODULE__{} = output) do
    Blake3.compress(
      output.input_chaining_value,
      output.block_words,
      output.counter,
      output.block_len,
      output.flags
    )
    |> Enum.take(8)
  end

  @spec root_output_bytes(t(), integer()) :: binary()
  def root_output_bytes(output, bytes) do
    root_output_bytes(output, 0, bytes, "")
  end

  defp root_output_bytes(%__MODULE__{} = _output, _counter, bytes, hash)
       when byte_size(hash) >= bytes do
    :binary.part(hash, 0, bytes)
  end

  defp root_output_bytes(%__MODULE__{} = output, counter, bytes, hash) do
    words =
      Blake3.compress(
        output.input_chaining_value,
        output.block_words,
        counter,
        output.block_len,
        output.flags ||| @root
      )

    hash =
      Enum.reduce(words, hash, fn word, hash ->
        hash <> <<word::little-32>>
      end)

    root_output_bytes(output, counter + 1, bytes, hash)
  end
end
