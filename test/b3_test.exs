defmodule B3Test do
  use ExUnit.Case
  doctest B3

  @vectors Jason.decode!(File.read!("./test/test_vectors.json"))

  for {vector, i} <- Enum.with_index(@vectors["cases"]) do
    test "hash vector #{i}" do
      %{"input_len" => len, "hash" => hash} = unquote(Macro.escape(vector))
      msg = message(len)
      assert B3.hash(msg, length: 131, encoding: :hex) == hash
      assert B3.hash(msg, encoding: :hex) == String.slice(hash, 0..63)
    end

    test "keyed hash vector #{i}" do
      %{"input_len" => len, "keyed_hash" => keyed_hash} = unquote(Macro.escape(vector))
      msg = message(len)
      assert B3.keyed_hash(msg, @vectors["key"], length: 131, encoding: :hex) == keyed_hash

      assert B3.keyed_hash(msg, @vectors["key"], encoding: :hex) ==
               String.slice(keyed_hash, 0..63)
    end

    test "key derivation vector #{i}" do
      %{"input_len" => len, "derive_key" => key} = unquote(Macro.escape(vector))
      msg = message(len)
      assert B3.derive_key(msg, @vectors["context_string"], length: 131, encoding: :hex) == key

      assert B3.derive_key(msg, @vectors["context_string"], encoding: :hex) ==
               String.slice(key, 0..63)
    end
  end

  # The input in each case is filled with a repeating sequence of 251 bytes:
  # 0, 1, 2, ..., 249, 250, 0, 1, ..., and so on.
  defp message(len, n \\ 0, msg \\ "")
  defp message(len, n, msg) when n == len, do: msg
  defp message(len, n, msg), do: message(len, n + 1, msg <> <<rem(n, 251)>>)
end
