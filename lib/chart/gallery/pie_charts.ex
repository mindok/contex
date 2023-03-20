defmodule Contex.Gallery.PieCharts do
  import Contex.Gallery.Sample, only: [graph: 1]

  @moduledoc """
  A gallery of Pie Charts.

  > #### Have one to share? {: .warning}
  >
  > Do you have an interesting plot you want to
  > share? Something you learned the hard way that
  > should be here, or that's just great to see?
  > Just open a ticket on GitHub and we'll post it here.


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
