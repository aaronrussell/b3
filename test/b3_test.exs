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

  describe "encoding and length options" do
    # Known hash of "test" from the official test vectors / doctests
    @test_hex "4878ca0425c739fa427f7eda20fe845f6b2e46ba5fe2a14df5b1e32f50603215"

    test "raw binary output (no encoding)" do
      raw = B3.hash("test")
      assert is_binary(raw)
      assert byte_size(raw) == 32
      assert Base.encode16(raw, case: :lower) == @test_hex
    end

    test ":base16 encoding returns uppercase hex" do
      assert B3.hash("test", encoding: :base16) == String.upcase(@test_hex)
    end

    test ":base64 encoding" do
      raw = B3.hash("test")
      assert B3.hash("test", encoding: :base64) == Base.encode64(raw)
    end

    test "custom length" do
      raw_16 = B3.hash("test", length: 16)
      raw_32 = B3.hash("test")
      assert byte_size(raw_16) == 16
      assert raw_16 == binary_part(raw_32, 0, 16)
    end

    test "empty string input" do
      assert byte_size(B3.hash("")) == 32
      assert byte_size(B3.keyed_hash("", "testkeytestkeytestkeytestkeytest")) == 32
      assert byte_size(B3.derive_key("", "context")) == 32
    end
  end

  # The input in each case is filled with a repeating sequence of 251 bytes:
  # 0, 1, 2, ..., 249, 250, 0, 1, ..., and so on.
  defp message(len, n \\ 0, msg \\ "")
  defp message(len, n, msg) when n == len, do: msg
  defp message(len, n, msg), do: message(len, n + 1, msg <> <<rem(n, 251)>>)
end
