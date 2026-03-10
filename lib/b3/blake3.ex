defmodule B3.Blake3 do
  @moduledoc false

  # BLAKE3 algorithm module.

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

  @iv {
    0x6A09E667,
    0xBB67AE85,
    0x3C6EF372,
    0xA54FF53A,
    0x510E527F,
    0x9B05688C,
    0x1F83D9AB,
    0x5BE0CD19
  }

  @typedoc "Initialization vector"
  @type iv() :: tuple()

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
  def params(:out_len), do: @out_len
  def params(:key_len), do: @key_len
  def params(:block_len), do: @block_len
  def params(:chunk_len), do: @chunk_len

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
  def flags(:chunk_start), do: @chunk_start
  def flags(:chunk_end), do: @chunk_end
  def flags(:parent), do: @parent
  def flags(:root), do: @root
  def flags(:keyed_hash), do: @keyed_hash
  def flags(:derive_key_context), do: @derive_key_context
  def flags(:derive_key_material), do: @derive_key_material

  @doc """
  Returns only the 8-word chaining value (first 8 XOR'd elements).
  Saves 8 bxor ops and halves the return tuple size vs compress/5.
  """
  @spec compress_cv(tuple(), binary() | tuple(), integer(), integer(), integer()) :: tuple()
  def compress_cv(
        {cv0, cv1, cv2, cv3, cv4, cv5, cv6, cv7},
        <<m0::little-32, m1::little-32, m2::little-32, m3::little-32, m4::little-32,
          m5::little-32, m6::little-32, m7::little-32, m8::little-32, m9::little-32,
          m10::little-32, m11::little-32, m12::little-32, m13::little-32, m14::little-32,
          m15::little-32>>,
        counter,
        block_len,
        flags
      ) do
    {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15} =
      mix(
        cv0,
        cv1,
        cv2,
        cv3,
        cv4,
        cv5,
        cv6,
        cv7,
        elem(@iv, 0),
        elem(@iv, 1),
        elem(@iv, 2),
        elem(@iv, 3),
        counter,
        counter >>> 32,
        block_len,
        flags,
        m0,
        m1,
        m2,
        m3,
        m4,
        m5,
        m6,
        m7,
        m8,
        m9,
        m10,
        m11,
        m12,
        m13,
        m14,
        m15
      )

    {bxor(s0, s8), bxor(s1, s9), bxor(s2, s10), bxor(s3, s11), bxor(s4, s12), bxor(s5, s13),
     bxor(s6, s14), bxor(s7, s15)}
  end

  def compress_cv(
        {cv0, cv1, cv2, cv3, cv4, cv5, cv6, cv7},
        {m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15},
        counter,
        block_len,
        flags
      ) do
    {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15} =
      mix(
        cv0,
        cv1,
        cv2,
        cv3,
        cv4,
        cv5,
        cv6,
        cv7,
        elem(@iv, 0),
        elem(@iv, 1),
        elem(@iv, 2),
        elem(@iv, 3),
        counter,
        counter >>> 32,
        block_len,
        flags,
        m0,
        m1,
        m2,
        m3,
        m4,
        m5,
        m6,
        m7,
        m8,
        m9,
        m10,
        m11,
        m12,
        m13,
        m14,
        m15
      )

    {bxor(s0, s8), bxor(s1, s9), bxor(s2, s10), bxor(s3, s11), bxor(s4, s12), bxor(s5, s13),
     bxor(s6, s14), bxor(s7, s15)}
  end

  @doc """
  Takes a 128-byte chunk and mixes it into the chaining value.
  Returns full 16-tuple state.
  """
  @spec compress(tuple(), binary() | tuple(), integer(), integer(), integer()) :: tuple()
  def compress(
        chaining_value,
        <<m0::little-32, m1::little-32, m2::little-32, m3::little-32, m4::little-32,
          m5::little-32, m6::little-32, m7::little-32, m8::little-32, m9::little-32,
          m10::little-32, m11::little-32, m12::little-32, m13::little-32, m14::little-32,
          m15::little-32>>,
        counter,
        block_len,
        flags
      ) do
    compress(
      chaining_value,
      {m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15},
      counter,
      block_len,
      flags
    )
  end

  def compress(
        chaining_value,
        {m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15},
        counter,
        block_len,
        flags
      ) do
    {cv0, cv1, cv2, cv3, cv4, cv5, cv6, cv7} = chaining_value

    {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15} =
      mix(
        cv0,
        cv1,
        cv2,
        cv3,
        cv4,
        cv5,
        cv6,
        cv7,
        elem(@iv, 0),
        elem(@iv, 1),
        elem(@iv, 2),
        elem(@iv, 3),
        counter,
        counter >>> 32,
        block_len,
        flags,
        m0,
        m1,
        m2,
        m3,
        m4,
        m5,
        m6,
        m7,
        m8,
        m9,
        m10,
        m11,
        m12,
        m13,
        m14,
        m15
      )

    {bxor(s0, s8), bxor(s1, s9), bxor(s2, s10), bxor(s3, s11), bxor(s4, s12), bxor(s5, s13),
     bxor(s6, s14), bxor(s7, s15), bxor(s8, cv0), bxor(s9, cv1), bxor(s10, cv2), bxor(s11, cv3),
     bxor(s12, cv4), bxor(s13, cv5), bxor(s14, cv6), bxor(s15, cv7)}
  end

  @doc """
  Converts a binary string into a tuple of integers.
  """
  @spec words_from_le_bytes(binary(), integer()) :: tuple()
  def words_from_le_bytes(bytes, len \\ 16)

  def words_from_le_bytes(
        <<w0::little-32, w1::little-32, w2::little-32, w3::little-32, w4::little-32,
          w5::little-32, w6::little-32, w7::little-32, w8::little-32, w9::little-32,
          w10::little-32, w11::little-32, w12::little-32, w13::little-32, w14::little-32,
          w15::little-32>>,
        16
      ) do
    {w0, w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15}
  end

  def words_from_le_bytes(
        <<w0::little-32, w1::little-32, w2::little-32, w3::little-32, w4::little-32,
          w5::little-32, w6::little-32, w7::little-32>>,
        8
      ) do
    {w0, w1, w2, w3, w4, w5, w6, w7}
  end

  def words_from_le_bytes(bytes, len) when byte_size(bytes) < len * 4 do
    padded = bytes <> :binary.copy(<<0>>, len * 4 - byte_size(bytes))
    words_from_le_bytes(padded, len)
  end

  # The BLAKE3 G mixing function. Expands at compile time to 8 arithmetic/rotation
  # operations that rebind the four state variables a, b, c, d in the caller's scope.
  defmacrop g(a, b, c, d, mx, my) do
    quote do
      unquote(a) = band(unquote(a) + unquote(b) + unquote(mx), 0xFFFFFFFF)
      unquote(d) = rotr(bxor(unquote(d), unquote(a)), 16)
      unquote(c) = band(unquote(c) + unquote(d), 0xFFFFFFFF)
      unquote(b) = rotr(bxor(unquote(b), unquote(c)), 12)
      unquote(a) = band(unquote(a) + unquote(b) + unquote(my), 0xFFFFFFFF)
      unquote(d) = rotr(bxor(unquote(d), unquote(a)), 8)
      unquote(c) = band(unquote(c) + unquote(d), 0xFFFFFFFF)
      unquote(b) = rotr(bxor(unquote(b), unquote(c)), 7)
    end
  end

  # 7-round mix on 16 bare state variables and 16 bare message words.
  # Each round applies 8 G-calls (4 columns + 4 diagonals) with message words
  # selected by the BLAKE3 permutation schedule P^N.
  #
  # G-call state mappings (same every round):
  #   Columns:   (s0,s4,s8,s12)  (s1,s5,s9,s13)  (s2,s6,s10,s14)  (s3,s7,s11,s15)
  #   Diagonals: (s0,s5,s10,s15) (s1,s6,s11,s12) (s2,s7,s8,s13)   (s3,s4,s9,s14)
  defp mix(
         s0,
         s1,
         s2,
         s3,
         s4,
         s5,
         s6,
         s7,
         s8,
         s9,
         s10,
         s11,
         s12,
         s13,
         s14,
         s15,
         m0,
         m1,
         m2,
         m3,
         m4,
         m5,
         m6,
         m7,
         m8,
         m9,
         m10,
         m11,
         m12,
         m13,
         m14,
         m15
       ) do
    # Round 0: [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
    g(s0, s4, s8, s12, m0, m1)
    g(s1, s5, s9, s13, m2, m3)
    g(s2, s6, s10, s14, m4, m5)
    g(s3, s7, s11, s15, m6, m7)
    g(s0, s5, s10, s15, m8, m9)
    g(s1, s6, s11, s12, m10, m11)
    g(s2, s7, s8, s13, m12, m13)
    g(s3, s4, s9, s14, m14, m15)
    # Round 1: [2,6,3,10,7,0,4,13,1,11,12,5,9,14,15,8]
    g(s0, s4, s8, s12, m2, m6)
    g(s1, s5, s9, s13, m3, m10)
    g(s2, s6, s10, s14, m7, m0)
    g(s3, s7, s11, s15, m4, m13)
    g(s0, s5, s10, s15, m1, m11)
    g(s1, s6, s11, s12, m12, m5)
    g(s2, s7, s8, s13, m9, m14)
    g(s3, s4, s9, s14, m15, m8)
    # Round 2: [3,4,10,12,13,2,7,14,6,5,9,0,11,15,8,1]
    g(s0, s4, s8, s12, m3, m4)
    g(s1, s5, s9, s13, m10, m12)
    g(s2, s6, s10, s14, m13, m2)
    g(s3, s7, s11, s15, m7, m14)
    g(s0, s5, s10, s15, m6, m5)
    g(s1, s6, s11, s12, m9, m0)
    g(s2, s7, s8, s13, m11, m15)
    g(s3, s4, s9, s14, m8, m1)
    # Round 3: [10,7,12,9,14,3,13,15,4,0,11,2,5,8,1,6]
    g(s0, s4, s8, s12, m10, m7)
    g(s1, s5, s9, s13, m12, m9)
    g(s2, s6, s10, s14, m14, m3)
    g(s3, s7, s11, s15, m13, m15)
    g(s0, s5, s10, s15, m4, m0)
    g(s1, s6, s11, s12, m11, m2)
    g(s2, s7, s8, s13, m5, m8)
    g(s3, s4, s9, s14, m1, m6)
    # Round 4: [12,13,9,11,15,10,14,8,7,2,5,3,0,1,6,4]
    g(s0, s4, s8, s12, m12, m13)
    g(s1, s5, s9, s13, m9, m11)
    g(s2, s6, s10, s14, m15, m10)
    g(s3, s7, s11, s15, m14, m8)
    g(s0, s5, s10, s15, m7, m2)
    g(s1, s6, s11, s12, m5, m3)
    g(s2, s7, s8, s13, m0, m1)
    g(s3, s4, s9, s14, m6, m4)
    # Round 5: [9,14,11,5,8,12,15,1,13,3,0,10,2,6,4,7]
    g(s0, s4, s8, s12, m9, m14)
    g(s1, s5, s9, s13, m11, m5)
    g(s2, s6, s10, s14, m8, m12)
    g(s3, s7, s11, s15, m15, m1)
    g(s0, s5, s10, s15, m13, m3)
    g(s1, s6, s11, s12, m0, m10)
    g(s2, s7, s8, s13, m2, m6)
    g(s3, s4, s9, s14, m4, m7)
    # Round 6: [11,15,5,0,1,9,8,6,14,10,2,12,3,4,7,13]
    g(s0, s4, s8, s12, m11, m15)
    g(s1, s5, s9, s13, m5, m0)
    g(s2, s6, s10, s14, m1, m9)
    g(s3, s7, s11, s15, m8, m6)
    g(s0, s5, s10, s15, m14, m10)
    g(s1, s6, s11, s12, m2, m12)
    g(s2, s7, s8, s13, m3, m4)
    g(s3, s4, s9, s14, m7, m13)

    {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15}
  end

  @spec rotr(integer(), integer()) :: integer()
  defp rotr(x, n) do
    band(bxor(x >>> n, x <<< (32 - n)), 0xFFFFFFFF)
  end
end
