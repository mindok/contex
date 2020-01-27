defprotocol Contex.Scale do
  @moduledoc """
  Provides a common interface for scales generating plotting coordinates.

  This enables Log & Linear scales, for example, to be handled exactly
  the same way in plot generation code.

  Example:
  ```
    # It doesn't matter if x & y scales are log, linear or discretizing scale
    x_tx_fn = Scale.domain_to_range_fn(x_scale)
    y_tx_fn = Scale.domain_to_range_fn(y_scale)

    points_to_plot = Enum.map(big_load_of_data, fn %{x: x, y: y}=_row ->
            {x_tx_fn.(x), y_tx_fn.(y)}
          end)
  ```
  """

  @doc """
  Returns a list of tick values in the domain of the scale

  Typically these are used to label the tick
  """
  @spec ticks_domain(t()) :: list(any())
  def ticks_domain(scale)

  @doc """
  Returns a list of tick locations in the range of the scale

  Typically these are used to plot the location of the tick
  """
  @spec ticks_range(t()) :: list(number())
  def ticks_range(scale)

  @doc """
  Returns a transform function to convert values within the domain to the
  range.

  Typically this function is used to calculate plotting coordinates for input data.
  """
  @spec domain_to_range_fn(t()) :: fun()
  def domain_to_range_fn(scale)

  @doc """
  Transforms a value in the domain to a plotting coordinate within the range
  """
  @spec domain_to_range(t(), any()) :: number()
  def domain_to_range(scale, domain_val)

  @doc """
  Returns the plotting range set for the scale

  Note that there is not an equivalent for the domain, as the domain is specific to
  the type of scale.
  """
  @spec get_range(t()) :: {number(), number()}
  def get_range(scale)

  @doc """
  Applies a plotting range set for the scale
  """
  @spec set_range(t(), number(), number()) :: t()
  def set_range(scale, start, finish)

  @doc """
  Formats a domain value according to formatting rules calculated for the scale.

  For example, timescales will have formatting rules calculated based on the
  overall time period being plotted. Numeric scales may calculate number of
  decimal places to show based on the range of data being plotted.
  """
  @spec get_formatted_tick(t(), number()) :: String.t()
  def get_formatted_tick(scale, tick_val)
end
