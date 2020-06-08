defmodule Contex.MixProject do
  use Mix.Project

  def project do
    [
      app: :contex,
      version: "0.3.0",
      elixir: "~> 1.9",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      name: "ContEx",
      source_url: "https://github.com/mindok/contex",
      homepage_url: "https://contex-charts.org/",
      deps: deps(),
      docs: docs()
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
      {:nimble_strftime, "~> 0.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:sweet_xml, "~> 0.6.6", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Contex",
      logo: "assets/logo.png"
    ]
  end

  defp package() do
    [
      name: "contex",
      # These are the default files included in the package
      files: ~w(lib mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mindok/contex",
        "Website" => "https://contex-charts.org/"
      }
    ]
  end
end
