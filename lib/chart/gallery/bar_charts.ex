defmodule Contex.Gallery.BarCharts do
  import Contex.Gallery.Sample, only: [graph: 1]

  @moduledoc """
  A gallery of Bar Charts.


  - `plain/0` - An introductory example


  > #### Have one to share? {: .warning}
  >
  > Do you have an interesting plot you want to
  > share? Something you learned the hard way that
  > should be here, or that's just great to see?
  > Just open a ticket on GitHub and we'll post it here.

  """

  @doc """
  Bar charts using a log scale.

  See `Contex.ContinuousLogScale` for details.


  #{graph(title: "A stacked sample",
  file: "bar_charts_log_stacked.sample",
  info: """
  This graph represents a distribution of values,
  rendered as a stacked sample.

  Notice how the large value difference (data is in minutes)
  makes a log scale mandatory, but the axis is not
  really readable on the far end.

  """)}

  #{graph(title: "A stacked sample with automatic domain and custom ticks",
  file: "bar_charts_log_stacked_auto_domain.sample",
  info: """
  This is the same data as above, but using a custom
  set of ticks that makes the values readable, and
  we get the axis domain out of the data-set.
  """)}

  """
  def with_log_scale(), do: 0

  @doc """
  Some plain charts.


  #{graph(title: "A simple vertical bar chart",
  file: "bar_charts_plain.sample",
  info: """
  Originally taken from https://github.com/mindok/contex/issues/74
  """)}



  #{graph(title: "A simple horizontal bar chart",
  file: "bar_charts_plain_horizontal.sample",
  info: """
  Originally taken from https://github.com/mindok/contex/issues/74
  """)}


  #{graph(title: "A simple stacked bar chart",
  file: "bar_charts_plain_stacked.sample",
  info: """
  Originally taken from https://github.com/mindok/contex/issues/74
  """)}


  """
  def plain(), do: 0
end
