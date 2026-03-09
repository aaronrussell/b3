defmodule B3.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/aaronrussell/b3"

  def project do
    [
      app: :b3,
      name: "B3",
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: pkg(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:jason, "~> 1.4", only: :test},
    ]
  end

  defp docs do
    [
      main: "B3",
      source_url: @source_url,
      homepage_url: @source_url,
    ]
  end

  defp pkg do
    [
      description: "B3 is a pure Elixir implementation of the BLAKE3 hashing algorithm.",
      licenses: ["Apache-2.0"],
      maintainers: ["Aaron Russell"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
