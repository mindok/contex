defmodule Contex.ScaleUtils do
  @doc """
  Makes sure that a range of numerics is
  a tuple of floats, in the right order.

  """
  def validate_range({f, t}, _label) when is_number(f) and is_number(t) do
    ff = as_float(f)
    tt = as_float(t)

    if tt < ff do
      {tt, ff}
    else
      {ff, tt}
    end
  end

  def validate_range(v, label),
    do:
      throw("#{label} - a range should be in the form {0.0, 1.0} but you supplied #{inspect(v)}")

  def as_float(n) when is_number(n) do
    case(n) do
      i when is_integer(i) -> i * 1.0
      f -> f
    end
  end

  @doc """
  Validates a range, that could be nil.
  """
  def validate_range_nil(nil, _label), do: nil
  def validate_range_nil(r, label), do: validate_range(r, label)

  def validate_option(o, option_name, possible_options)
      when is_binary(option_name) and is_list(possible_options) do
    if o in possible_options do
      o
    else
      throw(
        "Option #{option_name} cannot be set to #{o} - valid values are #{inspect(possible_options)} "
      )
    end
  end

  @doc """
  Rescales a value from domain to range.

  Expects

  (can be refactored in Lin)
  """
  def rescale_value(v, domain_min, domain_width, range_min, range_width) do
    if domain_width > 0.0 do
      ratio = (v - domain_min) / domain_width
      ratio * range_width + range_min
    else
      0.0
    end
  end

  @doc """
  Formats ticks.

  (can be refactored in Lin)
  """

  def format_tick_text(tick, _, custom_tick_formatter) when is_function(custom_tick_formatter),
    do: custom_tick_formatter.(tick)

  def format_tick_text(tick, _, _) when is_integer(tick), do: to_string(tick)

  def format_tick_text(tick, display_decimals, _) when display_decimals > 0 do
    :erlang.float_to_binary(tick, decimals: display_decimals)
  end

  def format_tick_text(tick, _, _), do: :erlang.float_to_binary(tick, [:compact, decimals: 0])

  @doc """
  Computes settings to display values.

      %{
        nice_domain: {min_nice, max_nice},
        interval_size: rounded_interval_size,
        interval_count: adjusted_interval_count,
        display_decimals: display_decimals
      }


  (can be refactored in Lin)
  """

  def compute_nice_settings(
        min_d,
        max_d,
        interval_count
      )
      when is_number(min_d) and is_number(max_d) and is_number(interval_count) and
             interval_count > 1 do
    width = max_d - min_d
    width = if width == 0.0, do: 1.0, else: width
    unrounded_interval_size = width / interval_count
    order_of_magnitude = :math.ceil(:math.log10(unrounded_interval_size) - 1)
    power_of_ten = :math.pow(10, order_of_magnitude)

    rounded_interval_size =
      lookup_axis_interval(unrounded_interval_size / power_of_ten) * power_of_ten

    min_nice = rounded_interval_size * Float.floor(min_d / rounded_interval_size)
    max_nice = rounded_interval_size * Float.ceil(max_d / rounded_interval_size)
    adjusted_interval_count = round(1.0001 * (max_nice - min_nice) / rounded_interval_size)

    display_decimals = guess_display_decimals(order_of_magnitude)

    %{
      nice_domain: {min_nice, max_nice},
      interval_size: rounded_interval_size,
      interval_count: adjusted_interval_count,
      display_decimals: display_decimals
    }
  end

  @axis_interval_breaks [0.05, 0.1, 0.2, 0.25, 0.4, 0.5, 1.0, 2.0, 2.5, 4.0, 5.0, 10.0, 20.0]
  defp lookup_axis_interval(raw_interval) when is_float(raw_interval) do
    Enum.find(@axis_interval_breaks, 10.0, fn x -> x >= raw_interval end)
  end

  defp guess_display_decimals(power_of_ten) when power_of_ten > 0 do
    0
  end

  defp guess_display_decimals(power_of_ten) do
    1 + -1 * round(power_of_ten)
  end
end
