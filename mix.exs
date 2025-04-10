defmodule EctoTrail.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :ecto_trail,
      description: description(),
      package: package(),
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]]
    ]
  end

  def description do
    "This package allows to add audit log that is based on Ecto changesets and stored in a separate table."
  end

  def application do
    [extra_applications: [:logger, :ecto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.14.0"},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.15.0", only: [:dev, :test]},
      {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
      {:credo, ">= 0.5.1", only: [:dev, :test]},
      {:ecto_enum, "~> 1.0"},
      {:benchee, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      contributors: ["Valiot, Nebo #15"],
      maintainers: ["Valiot"],
      licenses: ["LICENSE.md"],
      links: %{github: "https://github.com/Valiot/ecto_trail"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end
end
