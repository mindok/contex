defmodule Contex.Gallery.PieCharts do
  import Contex.Gallery.Sample, only: [graph: 1]

  @moduledoc """
  Some examples of pie charts.

  """

  @doc """
  Some plain pie charts.


  #{graph(title: "A simple pie chart",
  file: "pie_charts_plain.sample",
  info: """
  Originally taken from https://github.com/mindok/contex/issues/74
  """)}

  """
  def plain(), do: 0
end
