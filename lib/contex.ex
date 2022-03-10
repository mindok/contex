defmodule Contex do
  @moduledoc """
  Contex is a pure Elixir server-side data-plotting / charting system that generates SVG output.

  Contex is designed to be simple to use and extensible, relying on common core components, such
  as `Contex.Axis` and `Contex.Scale`, to create new plot types.

  The typical usage pattern is to wrap your data in a `Contex.Dataset`, pass that into a
  specific chart type (e.g. `Contex.BarChart`) to build the `Contex.PlotContent`, and then
  to lay that out using `Contex.Plot`, finally calling `Contex.Plot.to_svg(plot)` to create
  the SVG output.

  A minimal example might look like:
  ```
    data = [["Apples", 10], ["Bananas", 12], ["Pears", 2]]
    output =
      data
      |> Contex.Dataset.new()
      |> Contex.Plot.new(Contex.BarChart, 600, 400)
      |> Contex.Plot.to_svg()
  ```

  ## CSS Styling
  A minimal stylesheet is embedded in the SVG by default, for the purpose of making lines and text
  visible if no stylesheet is supplied. It is expected that these styles will be overridden using
  provided Contex-specific classes. The default style can also be removed by setting the
  `:default_style` Plot attribute to `false`.

  Sample CSS is shown below:
  ```css
  /* Styling for tick line */
  .exc-tick {
    stroke: grey;
  }

  /* Styling for tick text */
  .exc-tick text {
    fill: grey;
    stroke: none;
  }

  /* Styling for axis line */
  .exc-domain {
    stroke:  rgb(207, 207, 207);
  }

  /* Styling for grid line */
  .exc-grid {
    stroke: lightgrey;
  }

  /* Styling for outline of colours in legend */
  .exc-legend {
    stroke: black;
  }

  /* Styling for text of colours in legend */
  .exc-legend text {
    fill: grey;
    font-size: 0.8rem;
    stroke: none;
  }

  /* Styling for title & subtitle of any plot */
  .exc-title {
    fill: darkslategray;
    font-size: 2.3rem;
    stroke: none;
  }
  .exc-subtitle {
    fill: darkgrey;
    font-size: 1.0rem;
    stroke: none;
  }

  /* Styling for label printed inside a bar on a barchart */
  .exc-barlabel-in {
    fill: white;
    font-size: 0.7rem;
  }

  /* Styling for label printed outside of a bar (e.g. if bar is too small) */
  .exc-barlabel-out {
    fill: grey;
    font-size: 0.7rem;
  }
  ```

  """
end
