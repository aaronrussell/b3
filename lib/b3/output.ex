defmodule B3.Output do
  @moduledoc false
  import Bitwise
  alias B3.Blake3

  defstruct [:input_chaining_value, :block_words, :counter, :block_len, :flags]

  @type t() :: %__MODULE__{
          input_chaining_value: tuple(),
          block_words: tuple(),
          counter: integer(),
          block_len: integer(),
          flags: integer()
        }

  @root 1 <<< 3

  @spec chaining_value(t()) :: tuple()
  def chaining_value(%__MODULE__{} = output) do
    Blake3.compress_cv(
      output.input_chaining_value,
      output.block_words,
      output.counter,
      output.block_len,
      output.flags
    )
  end

  @spec root_output_bytes(t(), integer()) :: binary()
  def root_output_bytes(%__MODULE__{} = output, bytes) when bytes <= 32 do
    {w0, w1, w2, w3, w4, w5, w6, w7} =
      Blake3.compress_cv(
        output.input_chaining_value,
        output.block_words,
        0,
        output.block_len,
        output.flags ||| @root
      )

    hash =
      <<w0::little-32, w1::little-32, w2::little-32, w3::little-32, w4::little-32, w5::little-32,
        w6::little-32, w7::little-32>>

    binary_part(hash, 0, bytes)
  end

  def root_output_bytes(output, bytes) do
    root_output_bytes(output, 0, bytes, "")
  end

  defp root_output_bytes(%__MODULE__{} = _output, _counter, bytes, hash)
       when byte_size(hash) >= bytes do
    :binary.part(hash, 0, bytes)
  end

  defp root_output_bytes(%__MODULE__{} = output, counter, bytes, hash) do
    {w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15} =
      Blake3.compress(
        output.input_chaining_value,
        output.block_words,
        counter,
        output.block_len,
        output.flags ||| @root
      )

    block =
      <<w0::little-32, w1::little-32, w2::little-32, w3::little-32, w4::little-32, w5::little-32,
        w6::little-32, w7::little-32, w8::little-32, w9::little-32, w10::little-32,
        w11::little-32, w12::little-32, w13::little-32, w14::little-32, w15::little-32>>

    root_output_bytes(output, counter + 1, bytes, hash <> block)
  end
end
