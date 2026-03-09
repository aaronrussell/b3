context = "B3 2026-03-09 benchmark derive_key context"

inputs = %{
  "64 B" => :crypto.strong_rand_bytes(64),
  "1 KB" => :crypto.strong_rand_bytes(1_024),
  "64 KB" => :crypto.strong_rand_bytes(64 * 1_024),
  "1 MB" => :crypto.strong_rand_bytes(1_024 * 1_024)
}

Benchee.run(
  %{
    "B3.derive_key/2" => fn input -> B3.derive_key(input, context) end,
    "Blake3.derive_key/2" => fn input -> Blake3.derive_key(context, input) end
  },
  inputs: inputs,
  warmup: 2,
  time: 5,
  memory_time: 2
)
