defmodule Contex.MixProject do
  use Mix.Project

  def project do
    [
      app: :contex,
      version: "0.4.0",
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
    [
      extra_applications: [:eex]
    ]
  end

  defp description() do
    "Contex - a server-side charting library for Elixir."
  end

  defp deps do
    [
      {:nimble_strftime, "~> 0.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:sweet_xml, "~> 0.7.3", only: :test},
      {:floki, "~> 0.34.2", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Contex",
      logo: "assets/logo.png",
      assets: "assets",
      before_closing_head_tag: &docs_before_closing_head_tag/1
    ]
  end

  # Injects reference to contex.css into documentation output
  # See https://medium.com/@takanori.ishikawa/customize-how-your-exdoc-documentation-looks-a10234dbb4c9
  defp docs_before_closing_head_tag(:html) do
    ~s{<link rel="stylesheet" href="assets/contex.css">}
  end

  defp docs_before_closing_head_tag(_), do: ""

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
