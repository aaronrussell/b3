inputs = %{
  "64 B" => :crypto.strong_rand_bytes(64),
  "1 KB" => :crypto.strong_rand_bytes(1_024),
  "64 KB" => :crypto.strong_rand_bytes(64 * 1_024),
  "1 MB" => :crypto.strong_rand_bytes(1_024 * 1_024)
}

Benchee.run(
  %{
    "B3.hash/1" => fn input -> B3.hash(input) end,
    "Blake3.hash/1" => fn input -> Blake3.hash(input) end
  },
  inputs: inputs,
  warmup: 2,
  time: 5,
  memory_time: 2
)
