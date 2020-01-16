defmodule Contex.MixProject do
  use Mix.Project

  def project do
    [
      app: :contex,
      version: "0.1.0",
      elixir: "~> 1.9",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      name: "ContEx",
      source_url: "https://github.com/mindok/contex",
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp description() do
    "Contex - a server-side charting library for Elixir."
  end

  defp deps do
    [
      {:timex, "~> 3.6"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package() do
    [
      name: "contex",
      # These are the default files included in the package
      files: ~w(lib mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mindok/contex"}
    ]
  end
end
