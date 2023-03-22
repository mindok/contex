defmodule Contex.Gallery.PointPlots do
  import Contex.Gallery.Sample, only: [graph: 1]

  @moduledoc """
  A gallery of Line Charts.

  > #### Have one to share? {: .warning}
  >
  > Do you have an interesting plot you want to
  > share? Something you learned the hard way that
  > should be here, or that's just great to see?
  > Just open a ticket on GitHub and we'll post it here.


  """

  @doc """
  PointPlots using a log scale.

  #{graph(title: "Masked mode",
  file: "point_plots_log_masked.sample",
  info: """
  As negative numbers cannot be plotted with logarithms,
  as a default we just replace them with zeros (maked mode).
  """)}


  #{graph(title: "Symmetric mode",
  file: "point_plots_log_symmetric.sample",
  info: """
  As negative numbers cannot be plotted with logarithms,
  we can "make do" and use the symmetric mode.
  """)}

  #{graph(title: "Linear mode",
  file: "point_plots_log_masked_linear.sample",
  info: """
  As numbers below zero are negative as logarithms,
  and may get really big fast, you may want to
  "linearize" them.

  This works in masked mode (as shown) but also in
  symmetric mode.
  """)}

  #{graph(title: "Automatic range",
  file: "point_plots_log_masked_autorange.sample",
  info: """
  You can have the logscale "infer" the domain from
  data, so you don't have to think twice about it.
  """)}

  """
  def with_log_scale(), do: 0
end
