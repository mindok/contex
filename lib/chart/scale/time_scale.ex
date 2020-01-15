defmodule Contex.TimeScale do
  alias __MODULE__
  alias Timex.Format.DateTime.Formatters.Default, as: DateFormatter

  alias Contex.Utils

  # Approximate durations in ms for calculating ideal tick intervals
  # Modelled from https://github.com/d3/d3-scale/blob/v2.2.2/src/time.js
  @duration_sec 1000
  @duration_min @duration_sec * 60
  @duration_hour @duration_min * 60
  @duration_day @duration_hour * 24
  #@duration_week @duration_day * 7
  @duration_month @duration_day * 30
  @duration_year @duration_day * 365

  #Tuple defines: 1&2 - actual time intervals to calculate tick offsets & 3, approximate time interval to determine if this is the best option
  @default_tick_intervals [
    {:second, 1, @duration_sec},
    {:second, 5, @duration_sec * 5},
    {:second, 15, @duration_sec * 15},
    {:second, 30, @duration_sec * 30},
    {:minute, 1, @duration_min},
    {:minute, 5, @duration_min * 5},
    {:minute, 15, @duration_min * 15},
    {:minute, 30, @duration_min * 30},
    {:hour, 1, @duration_hour },
    {:hour, 3, @duration_hour * 3},
    {:hour, 6, @duration_hour * 6},
    {:hour, 12, @duration_hour * 12},
    {:day, 1, @duration_day },
    {:day, 2, @duration_day * 2},
    {:day, 5, @duration_day * 5},
    # {:week, 1, @duration_week }, #TODO: Need to work on tick_interval lookup function & related to make this work
    {:day, 10, @duration_day * 10},
    {:month, 1, @duration_month },
    {:month, 3, @duration_month * 3},
    {:year, 1, @duration_year}
  ]

  defstruct [:domain, :nice_domain, :range,
    :domain_to_range_fn, :range_to_domain_fn, :interval_count, :tick_interval,
    :custom_tick_formatter, :display_format]

  def new() do
    %TimeScale{range: {0.0, 1.0}, interval_count: 10}
  end

  def interval_count(%TimeScale{} = scale, interval_count) when is_integer(interval_count) and interval_count > 1 do
    %{scale | interval_count: interval_count}
    |> nice
    |> update_transform_funcs
  end
  def interval_count(%TimeScale{} = scale, _), do: scale

  def domain(%TimeScale{} = scale, min, max) do
    # We can be flexible with the range start > end, but the domain needs to start from the min
    {d_min, d_max} = case Utils.date_compare(min, max) do
      :lt -> {min, max}
      _ -> {max, min}
    end

    %{scale | domain: {d_min, d_max}}
    |> nice
    |> update_transform_funcs
  end
  def domain(%TimeScale{} = scale, data) when is_list(data) do
    {min, max} = extents(data)
    domain(scale, min, max)
  end

  # NOTE: interval count will likely get adjusted down here to keep things looking nice
  # TODO: no type checks on the domain
  defp nice(%TimeScale{domain: {min_d, max_d}, interval_count: interval_count} = scale)
       when is_number(interval_count) and interval_count > 1
    do
    width = Timex.diff(max_d, min_d, :milliseconds)
    unrounded_interval_size = width / (interval_count - 1)
    tick_interval = lookup_tick_interval(unrounded_interval_size)

    min_nice = round_down_to(min_d, tick_interval)
    {max_nice, adjusted_interval_count} = calculate_end_interval(min_nice, max_d, tick_interval, interval_count)

    display_format  = guess_display_format(tick_interval)

    %{scale | nice_domain: {min_nice, max_nice}, tick_interval: tick_interval, interval_count: adjusted_interval_count, display_format: display_format}
  end
  defp nice(%TimeScale{} = scale), do: scale

  defp lookup_tick_interval(raw_interval) when is_number(raw_interval) do
    result = Enum.find(@default_tick_intervals, fn {_,_,duration} -> duration >= raw_interval end)
    case result do
      nil -> Enum.take(@default_tick_intervals, -1)
      v -> v
    end
  end

  defp calculate_end_interval(start, target, {interval_type, interval_size, _}, max_steps) do
      Enum.reduce_while(1..max_steps, {start, 0}, fn step, {_current_end, _index} ->
        new_end = add_interval(start, interval_type, (step * interval_size))
        if (Utils.date_compare(new_end, target) == :lt), do: {:cont, {new_end, step}}, else: {:halt, {new_end, step}}
      end)
  end

  def add_interval(dt, :second, intervals), do: Timex.shift(dt, seconds: intervals)
  def add_interval(dt, :minute, intervals), do: Timex.shift(dt, minutes: intervals)
  def add_interval(dt, :hour, intervals), do: Timex.shift(dt, hours: intervals)
  def add_interval(dt, :day, intervals), do: Timex.shift(dt, days: intervals)
  def add_interval(dt, :month, intervals), do: Timex.shift(dt, months: intervals)
  def add_interval(dt, :year, intervals), do: Timex.shift(dt, years: intervals)

  #NOTE: Don't try this at home kiddies. Relies on internal representations of DateTime and NaiveDateTime
  defp round_down_to(dt, {:second, n, _}), do: %{dt | microsecond: {0,0}, second: round_down_multiple(dt.second, n)}
  defp round_down_to(dt, {:minute, n, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: round_down_multiple(dt.minute, n)}
  defp round_down_to(dt, {:hour, n, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: 0, hour: round_down_multiple(dt.hour, n)}
  defp round_down_to(dt, {:day, 1, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: 0, hour: 0}
  defp round_down_to(dt, {:day, n, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: 0, hour: 0, day: round_down_multiple(dt.day, n) + 1}
  defp round_down_to(dt, {:month, n, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: 0, hour: 0, day: 1, month: round_down_multiple(dt.month, n) + 1}
  defp round_down_to(dt, {:year, 1, _}), do: %{dt | microsecond: {0,0}, second: 0, minute: 0, hour: 0, day: 1, month: 1}

  defp guess_display_format({:second, _, _}), do: "{m}:{s}"
  defp guess_display_format({:minute, _, _}), do: "{h24}:{m}:{s}"
  defp guess_display_format({:hour, 1, _}), do: "{ISOtime}"
  defp guess_display_format({:hour, _, _}), do: "{D} {Mshort} {h24}:{m}"
  defp guess_display_format({:day, _, _}), do: "{ISOdate}"
  defp guess_display_format({:month, _, _}), do: "{Mshort} {YYYY}"
  defp guess_display_format({:year, _, _}), do: "{YYYY}"

  def update_transform_funcs(%TimeScale{nice_domain: {min_d, max_d}, range: {min_r, max_r}} = scale)
       when is_number(min_r) and is_number(max_r)
    do
    domain_width = Timex.diff(max_d, min_d, :microsecond)
    domain_min = 0

    range_width = max_r - min_r

    domain_to_range_fn = case domain_width do
      0 -> fn x -> x end
      _ ->
        fn domain_val ->
          milliseconds_val = Timex.diff(domain_val, min_d, :microsecond)
          ratio = (milliseconds_val - domain_min) / domain_width
          min_r + (ratio * range_width)
        end
    end

    range_to_domain_fn = case range_width do
      0 -> fn x -> x end
      _ ->
        fn range_val ->
          ratio = (range_val - min_r) / range_width
          Timex.add(min_d, Timex.Duration.from_microseconds(trunc(ratio * domain_width)))
        end
    end

    %{scale | domain_to_range_fn: domain_to_range_fn, range_to_domain_fn: range_to_domain_fn}
  end
  def update_transform_funcs(%TimeScale{} = scale), do: scale

  def extents(data) do
    Enum.reduce(data, {nil, nil}, fn x, {min, max} ->
      {Utils.safe_min(x, min), Utils.safe_max(x, max)}
    end)
  end

  defp round_down_multiple(value, multiple), do: div(value, multiple) * multiple


  defimpl Contex.Scale do
    def domain_to_range_fn(%TimeScale{domain_to_range_fn: domain_to_range_fn}), do: domain_to_range_fn

    def ticks_domain(%TimeScale{nice_domain: {min_d, _}, interval_count: interval_count, tick_interval: {interval_type, interval_size, _}})
      when is_number(interval_count)
    do
      0..interval_count
      |> Enum.map(fn i -> TimeScale.add_interval(min_d, interval_type, (i * interval_size)) end)
    end
    def ticks_domain(_), do: []

    def ticks_range(%TimeScale{domain_to_range_fn: transform_func} = scale) when is_function(transform_func) do
      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range(%TimeScale{domain_to_range_fn: transform_func}, range_val) when is_function(transform_func) do
      transform_func.(range_val)
    end

    def get_range(%TimeScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%TimeScale{} = scale, start, finish) when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
      |> TimeScale.update_transform_funcs
    end
    def set_range(%TimeScale{} = scale, {start, finish}) when is_number(start) and is_number(finish), do: set_range(scale, start, finish)


    def get_formatted_tick(%TimeScale{display_format: display_format, custom_tick_formatter: custom_tick_formatter}, tick_val) do
      format_tick_text(tick_val, display_format, custom_tick_formatter)
    end

    defp format_tick_text(tick, _, custom_tick_formatter) when is_function(custom_tick_formatter), do: custom_tick_formatter.(tick)
    defp format_tick_text(tick, display_format, _) do
      {:ok, result} = DateFormatter.format(tick, display_format)
      result
    end

  end

end
