defmodule Contex.Gallery.BarCharts do
  import Contex.Gallery.Sample, only: [graph: 1]

  @moduledoc """
  Some examples of bar charts

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
  Broken graphs.

  #{graph(title: "A broken graph",
  file: "bar_charts_log_stacked_empty.sample",
  info: """
  Not sure what this was.
  """)}



  """

  def broken(), do: 0
end
