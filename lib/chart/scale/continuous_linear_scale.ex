defmodule Contex.ContinuousLinearScale do
  @moduledoc """
  A linear scale to map continuous numberic data to a plotting coordinate system.

  Implements the general aspects of scale setup and use defined in the `Contex.Scale` protocol

  The `ContinuousLinearScale` is responsible for mapping to and from values in the data
  to a visual scale. The two key concepts are "domain" and "range".

  The "domain" represents values in the dataset to be plotted.

  The "range" represents the plotting coordinate system use to plot values in the "domain".

  *Important Note* - When you set domain and range, the scale code makes a few adjustments
  based on the desired number of tick intervals so that the ticks look "nice" - i.e. on
  round numbers. So if you have a data range of 0.0 &rarr; 8.7 and you want 10 intervals the scale
  won't display ticks at 0.0, 0.87, 1.74 etc, it will round up the domain to 10 so you have nice
  tick intervals of 0, 1, 2, 3 etc.

  By default the scale creates 10 tick intervals.

  When domain and range are both set, the scale makes transform functions available to map each way
  between the domain and range that are then available to the various plots to map data
  to plotting coordinate systems, and potentially vice-versa.

  The typical setup of the scale looks like this:

  ```
  y_scale
    = ContinuousLinearScale.new()
      |> ContinuousLinearScale.domain(min_value, max_value)
      |> Scale.set_range(start_of_y_plotting_coord, end_of_y_plotting_coord)
  ```

  Translating a value to plotting coordinates would then look like this:

  ```
  plot_y = Scale.domain_to_range(y_scale, y_value)
  ```

  `ContinuousLinearScale` implements the `Contex.Scale` protocol that provides a nicer way to access the
  transform functions. Calculation of plotting coordinates is typically done in tight loops
  so you are more likely to do something like than translating a single value as per the above example:

  ```
    x_tx_fn = Scale.domain_to_range_fn(x_scale)
    y_tx_fn = Scale.domain_to_range_fn(y_scale)

    points_to_plot = Enum.map(big_load_of_data, fn %{x: x, y: y}=_row ->
            {x_tx_fn.(x), y_tx_fn.(y)}
          end)
  ```

  """

  alias __MODULE__
  alias Contex.Utils

  defstruct [
    :domain,
    :nice_domain,
    :range,
    :interval_count,
    :interval_size,
    :display_decimals,
    :custom_tick_formatter
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new scale with defaults
  """
  @spec new :: Contex.ContinuousLinearScale.t()
  def new() do
    %ContinuousLinearScale{range: {0.0, 1.0}, interval_count: 10, display_decimals: nil}
  end

  @doc """
  Defines the number of intervals between ticks.

  Defaults to 10.

  Tick-rendering is the responsibility of `Contex.Axis`, but calculating tick intervals is the responsibility
  of the scale.
  """
  @spec interval_count(Contex.ContinuousLinearScale.t(), integer()) ::
          Contex.ContinuousLinearScale.t()
  def interval_count(%ContinuousLinearScale{} = scale, interval_count)
      when is_integer(interval_count) and interval_count > 1 do
    scale
    |> struct(interval_count: interval_count)
    |> nice()
  end

  def interval_count(%ContinuousLinearScale{} = scale, _), do: scale

  @doc """
  Sets the extents of the value domain for the scale.
  """
  @spec domain(Contex.ContinuousLinearScale.t(), number, number) ::
          Contex.ContinuousLinearScale.t()
  def domain(%ContinuousLinearScale{} = scale, min, max) when is_number(min) and is_number(max) do
    # We can be flexible with the range start > end, but the domain needs to start from the min
    {d_min, d_max} =
      case min < max do
        true -> {min, max}
        _ -> {max, min}
      end

    scale
    |> struct(domain: {d_min, d_max})
    |> nice()
  end

  @doc """
  Sets the extents of the value domain for the scale by specifying a list of values to be displayed.

  The scale will determine the extents of the data.
  """
  @spec domain(Contex.ContinuousLinearScale.t(), list(number())) ::
          Contex.ContinuousLinearScale.t()
  def domain(%ContinuousLinearScale{} = scale, data) when is_list(data) do
    {min, max} = extents(data)
    domain(scale, min, max)
  end

  # NOTE: interval count will likely get adjusted down here to keep things looking nice
  defp nice(
         %ContinuousLinearScale{domain: {min_d, max_d}, interval_count: interval_count} = scale
       )
       when is_number(min_d) and is_number(max_d) and is_number(interval_count) and
              interval_count > 1 do
    width = max_d - min_d
    width = if width == 0.0, do: 1.0, else: width
    unrounded_interval_size = width / (interval_count - 1)
    order_of_magnitude = :math.ceil(:math.log10(unrounded_interval_size) - 1)
    power_of_ten = :math.pow(10, order_of_magnitude)

    rounded_interval_size =
      lookup_axis_interval(unrounded_interval_size / power_of_ten) * power_of_ten

    min_nice = rounded_interval_size * Float.floor(min_d / rounded_interval_size)
    max_nice = rounded_interval_size * Float.ceil(max_d / rounded_interval_size)
    adjusted_interval_count = round(1.0001 * (max_nice - min_nice) / rounded_interval_size)

    display_decimals = guess_display_decimals(order_of_magnitude)

    %{
      scale
      | nice_domain: {min_nice, max_nice},
        interval_size: rounded_interval_size,
        interval_count: adjusted_interval_count,
        display_decimals: display_decimals
    }
  end

  defp nice(%ContinuousLinearScale{} = scale), do: scale

  @axis_interval_breaks [0.1, 0.2, 0.25, 0.4, 0.5, 1.0, 2.0, 2.5, 4.0, 5.0, 10.0]
  defp lookup_axis_interval(raw_interval) when is_float(raw_interval) do
    Enum.find(@axis_interval_breaks, fn x -> x >= raw_interval end)
  end

  defp guess_display_decimals(power_of_ten) when power_of_ten > 0 do
    0
  end

  defp guess_display_decimals(power_of_ten) do
    1 + -1 * round(power_of_ten)
  end

  @doc false
  def get_domain_to_range_function(%ContinuousLinearScale{
        nice_domain: {min_d, max_d},
        range: {min_r, max_r}
      })
      when is_number(min_d) and is_number(max_d) and is_number(min_r) and is_number(max_r) do
    domain_width = max_d - min_d
    range_width = max_r - min_r

    case domain_width do
      0 ->
        fn x -> x end

      0.0 ->
        fn x -> x end

      _ ->
        fn domain_val ->
          ratio = (domain_val - min_d) / domain_width
          min_r + ratio * range_width
        end
    end
  end

  def get_domain_to_range_function(_), do: fn x -> x end

  @doc false
  def get_range_to_domain_function(%ContinuousLinearScale{
        nice_domain: {min_d, max_d},
        range: {min_r, max_r}
      })
      when is_number(min_d) and is_number(max_d) and is_number(min_r) and is_number(max_r) do
    domain_width = max_d - min_d
    range_width = max_r - min_r

    case range_width do
      0 ->
        fn x -> x end

      0.0 ->
        fn x -> x end

      _ ->
        fn range_val ->
          ratio = (range_val - min_r) / range_width
          min_d + ratio * domain_width
        end
    end
  end

  def get_range_to_domain_function(_), do: fn x -> x end

  @doc false
  def extents(data) do
    Enum.reduce(data, {nil, nil}, fn x, {min, max} ->
      {Utils.safe_min(x, min), Utils.safe_max(x, max)}
    end)
  end

  defimpl Contex.Scale do
    def domain_to_range_fn(%ContinuousLinearScale{} = scale),
      do: ContinuousLinearScale.get_domain_to_range_function(scale)

    def ticks_domain(%ContinuousLinearScale{
          nice_domain: {min_d, _},
          interval_count: interval_count,
          interval_size: interval_size
        })
        when is_number(min_d) and is_number(interval_count) and is_number(interval_size) do
      0..interval_count
      |> Enum.map(fn i -> min_d + i * interval_size end)
    end

    def ticks_domain(_), do: []

    def ticks_range(%ContinuousLinearScale{} = scale) do
      transform_func = ContinuousLinearScale.get_domain_to_range_function(scale)

      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range(%ContinuousLinearScale{} = scale, range_val) do
      transform_func = ContinuousLinearScale.get_domain_to_range_function(scale)
      transform_func.(range_val)
    end

    def get_range(%ContinuousLinearScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%ContinuousLinearScale{} = scale, start, finish)
        when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
    end

    def set_range(%ContinuousLinearScale{} = scale, {start, finish})
        when is_number(start) and is_number(finish),
        do: set_range(scale, start, finish)

    def get_formatted_tick(
          %ContinuousLinearScale{
            display_decimals: display_decimals,
            custom_tick_formatter: custom_tick_formatter
          },
          tick_val
        ) do
      format_tick_text(tick_val, display_decimals, custom_tick_formatter)
    end

    defp format_tick_text(tick, _, custom_tick_formatter) when is_function(custom_tick_formatter),
      do: custom_tick_formatter.(tick)

    defp format_tick_text(tick, _, _) when is_integer(tick), do: to_string(tick)

    defp format_tick_text(tick, display_decimals, _) when display_decimals > 0 do
      :erlang.float_to_binary(tick, decimals: display_decimals)
    end

    defp format_tick_text(tick, _, _), do: :erlang.float_to_binary(tick, [:compact, decimals: 0])
  end
end
