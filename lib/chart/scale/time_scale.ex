defmodule Contex.TimeScale do
  @moduledoc """
  A time scale to map date and time data to a plotting coordinate system.

  Almost identical `Contex.ContinuousLinearScale` in terms of concepts and
  usage, except it applies to `DateTime` and `NaiveDateTime` domain data
  types.

  `TimeScale` handles the complexities of calculating nice tick intervals etc
  for almost any time range between a few seconds and a few years.

  """
  alias __MODULE__

  alias Contex.Utils

  @type datetimes() :: NaiveDateTime.t() | DateTime.t()

  # Approximate durations in ms for calculating ideal tick intervals
  # Modelled from https://github.com/d3/d3-scale/blob/v2.2.2/src/time.js
  @duration_sec 1000
  @duration_min @duration_sec * 60
  @duration_hour @duration_min * 60
  @duration_day @duration_hour * 24
  # @duration_week @duration_day * 7
  @duration_month @duration_day * 30
  @duration_year @duration_day * 365

  # Tuple defines: 1&2 - actual time intervals to calculate tick offsets & 3,
  # approximate time interval to determine if this is the best option
  @default_tick_intervals [
    {:seconds, 1, @duration_sec},
    {:seconds, 5, @duration_sec * 5},
    {:seconds, 15, @duration_sec * 15},
    {:seconds, 30, @duration_sec * 30},
    {:minutes, 1, @duration_min},
    {:minutes, 5, @duration_min * 5},
    {:minutes, 15, @duration_min * 15},
    {:minutes, 30, @duration_min * 30},
    {:hours, 1, @duration_hour},
    {:hours, 3, @duration_hour * 3},
    {:hours, 6, @duration_hour * 6},
    {:hours, 12, @duration_hour * 12},
    {:days, 1, @duration_day},
    {:days, 2, @duration_day * 2},
    {:days, 5, @duration_day * 5},
    # {:week, 1, @duration_week }, #TODO: Need to work on tick_interval lookup function & related to make this work
    {:days, 10, @duration_day * 10},
    {:months, 1, @duration_month},
    {:months, 3, @duration_month * 3},
    {:years, 1, @duration_year}
  ]

  defstruct [
    :domain,
    :nice_domain,
    :range,
    :interval_count,
    :tick_interval,
    :custom_tick_formatter,
    :display_format
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new TimeScale struct with basic defaults set
  """
  @spec new :: Contex.TimeScale.t()
  def new() do
    %TimeScale{range: {0.0, 1.0}, interval_count: 11}
  end

  @doc """
  Specifies the number of intervals the scale should display.

  Default is 10.
  """
  @spec interval_count(Contex.TimeScale.t(), integer()) :: Contex.TimeScale.t()
  def interval_count(%TimeScale{} = scale, interval_count)
      when is_integer(interval_count) and interval_count > 1 do
    scale
    |> struct(interval_count: interval_count)
    |> nice()
  end

  def interval_count(%TimeScale{} = scale, _), do: scale

  @doc """
  Define the data domain for the scale
  """
  @spec domain(Contex.TimeScale.t(), datetimes(), datetimes()) :: Contex.TimeScale.t()
  def domain(%TimeScale{} = scale, min, max) do
    # We can be flexible with the range start > end, but the domain needs to start from the min
    {d_min, d_max} =
      case Utils.date_compare(min, max) do
        :lt -> {min, max}
        _ -> {max, min}
      end

    scale
    |> struct(domain: {d_min, d_max})
    |> nice()
  end

  @doc """
  Define the data domain for the scale from a list of data.

  Extents will be calculated by the scale.
  """
  @spec domain(Contex.TimeScale.t(), list(datetimes())) :: Contex.TimeScale.t()
  def domain(%TimeScale{} = scale, data) when is_list(data) do
    {min, max} = extents(data)
    domain(scale, min, max)
  end

  # NOTE: interval count will likely get adjusted down here to keep things looking nice
  # TODO: no type checks on the domain
  defp nice(%TimeScale{domain: {min_d, max_d}, interval_count: interval_count} = scale)
       when is_number(interval_count) and interval_count > 1 do
    width = Utils.date_diff(max_d, min_d, :millisecond)
    unrounded_interval_size = width / (interval_count - 1)
    tick_interval = lookup_tick_interval(unrounded_interval_size)

    min_nice = round_down_to(min_d, tick_interval)

    {max_nice, adjusted_interval_count} =
      calculate_end_interval(min_nice, max_d, tick_interval, interval_count)

    display_format = guess_display_format(tick_interval)

    %{
      scale
      | nice_domain: {min_nice, max_nice},
        tick_interval: tick_interval,
        interval_count: adjusted_interval_count,
        display_format: display_format
    }
  end

  defp nice(%TimeScale{} = scale), do: scale

  defp lookup_tick_interval(raw_interval) when is_number(raw_interval) do
    default = List.last(@default_tick_intervals)
    Enum.find(@default_tick_intervals, default, &(elem(&1, 2) >= raw_interval))
  end

  defp calculate_end_interval(start, target, tick_interval, max_steps) do
    Enum.reduce_while(1..max_steps, {start, 0}, fn step, {_current_end, _index} ->
      new_end = add_interval(start, tick_interval, step)

      if Utils.date_compare(new_end, target) == :lt,
        do: {:cont, {new_end, step}},
        else: {:halt, {new_end, step}}
    end)
  end

  @doc false
  def add_interval(dt, {:seconds, _, duration_msec}, count),
    do: Utils.date_add(dt, duration_msec * count, :millisecond)

  def add_interval(dt, {:minutes, _, duration_msec}, count),
    do: Utils.date_add(dt, duration_msec * count, :millisecond)

  def add_interval(dt, {:hours, _, duration_msec}, count),
    do: Utils.date_add(dt, duration_msec * count, :millisecond)

  def add_interval(dt, {:days, _, duration_msec}, count),
    do: Utils.date_add(dt, duration_msec * count, :millisecond)

  def add_interval(dt, {:months, interval_size, _}, count),
    do: Utils.date_add(dt, interval_size * count, :months)

  def add_interval(dt, {:years, interval_size, _}, count),
    do: Utils.date_add(dt, interval_size * count, :years)

  # NOTE: Don't try this at home kiddies. Relies on internal representations of DateTime and NaiveDateTime
  defp round_down_to(dt, {:seconds, n, _}),
    do: %{dt | microsecond: {0, 0}, second: round_down_multiple(dt.second, n)}

  defp round_down_to(dt, {:minutes, n, _}),
    do: %{dt | microsecond: {0, 0}, second: 0, minute: round_down_multiple(dt.minute, n)}

  defp round_down_to(dt, {:hours, n, _}),
    do: %{dt | microsecond: {0, 0}, second: 0, minute: 0, hour: round_down_multiple(dt.hour, n)}

  defp round_down_to(dt, {:days, 1, _}),
    do: %{dt | microsecond: {0, 0}, second: 0, minute: 0, hour: 0}

  defp round_down_to(dt, {:days, n, _}),
    do: %{
      dt
      | microsecond: {0, 0},
        second: 0,
        minute: 0,
        hour: 0,
        day: round_down_multiple(dt.day, n) + 1
    }

  defp round_down_to(dt, {:months, 1, _}),
    do: %{dt | microsecond: {0, 0}, second: 0, minute: 0, hour: 0, day: 1}

  defp round_down_to(dt, {:months, n, _}), do: round_down_month(dt, n)

  defp round_down_to(dt, {:years, 1, _}),
    do: %{dt | microsecond: {0, 0}, second: 0, minute: 0, hour: 0, day: 1, month: 1}

  defp round_down_month(dt, n) do
    month = round_down_multiple(dt.month, n)
    year = dt.year

    {month, year} =
      case month > 0 do
        true -> {month, year}
        _ -> {month + 12, year - 1}
      end

    day = :calendar.last_day_of_the_month(year, month)
    %{dt | microsecond: {0, 0}, second: 0, minute: 0, hour: 0, day: day, month: month, year: year}
  end

  defp guess_display_format({:seconds, _, _}), do: "%M:%S"
  defp guess_display_format({:minutes, _, _}), do: "%H:%M:%S"
  defp guess_display_format({:hours, 1, _}), do: "%H:%M:%S"
  defp guess_display_format({:hours, _, _}), do: "%d %b %H:%M"
  defp guess_display_format({:days, _, _}), do: "%d %b"
  defp guess_display_format({:months, _, _}), do: "%b %Y"
  defp guess_display_format({:years, _, _}), do: "%Y"

  @doc false
  def get_domain_to_range_function(%TimeScale{nice_domain: {min_d, max_d}, range: {min_r, max_r}})
      when is_number(min_r) and is_number(max_r) do
    domain_width = Utils.date_diff(max_d, min_d, :microsecond)
    domain_min = 0

    range_width = max_r - min_r

    case domain_width do
      0 ->
        fn x -> x end

      _ ->
        fn domain_val ->
          milliseconds_val = Utils.date_diff(domain_val, min_d, :microsecond)
          ratio = (milliseconds_val - domain_min) / domain_width
          min_r + ratio * range_width
        end
    end
  end

  def get_domain_to_range_function(_), do: fn x -> x end

  @doc false
  def get_range_to_domain_function(%TimeScale{nice_domain: {min_d, max_d}, range: {min_r, max_r}})
      when is_number(min_r) and is_number(max_r) do
    domain_width = Utils.date_diff(max_d, min_d, :microsecond)
    range_width = max_r - min_r

    case range_width do
      0 ->
        fn x -> x end

      _ ->
        fn range_val ->
          ratio = (range_val - min_r) / range_width
          Utils.date_add(min_d, trunc(ratio * domain_width), :microsecond)
        end
    end
  end

  def get_range_to_domain_function(_), do: fn x -> x end

  defp extents(data) do
    Enum.reduce(data, {nil, nil}, fn x, {min, max} ->
      {Utils.safe_min(x, min), Utils.safe_max(x, max)}
    end)
  end

  defp round_down_multiple(value, multiple), do: div(value, multiple) * multiple

  defimpl Contex.Scale do
    def domain_to_range_fn(%TimeScale{} = scale),
      do: TimeScale.get_domain_to_range_function(scale)

    def ticks_domain(%TimeScale{
          nice_domain: {min_d, _},
          interval_count: interval_count,
          tick_interval: tick_interval
        })
        when is_number(interval_count) do
      0..interval_count
      |> Enum.map(fn i -> TimeScale.add_interval(min_d, tick_interval, i) end)
    end

    def ticks_domain(_), do: []

    def ticks_range(%TimeScale{} = scale) do
      transform_func = TimeScale.get_domain_to_range_function(scale)

      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range(%TimeScale{} = scale, range_val) do
      transform_func = TimeScale.get_domain_to_range_function(scale)
      transform_func.(range_val)
    end

    def get_range(%TimeScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%TimeScale{} = scale, start, finish)
        when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
    end

    def set_range(%TimeScale{} = scale, {start, finish})
        when is_number(start) and is_number(finish),
        do: set_range(scale, start, finish)

    def get_formatted_tick(
          %TimeScale{
            display_format: display_format,
            custom_tick_formatter: custom_tick_formatter
          },
          tick_val
        ) do
      format_tick_text(tick_val, display_format, custom_tick_formatter)
    end

    defp format_tick_text(tick, _, custom_tick_formatter) when is_function(custom_tick_formatter),
      do: custom_tick_formatter.(tick)

    defp format_tick_text(tick, display_format, _),
      do: NimbleStrftime.format(tick, display_format)
  end
end
