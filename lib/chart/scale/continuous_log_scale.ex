defmodule Contex.ContinuousLogScale do
  @moduledoc """
  A logarithmic scale to map continuous numeric data to a plotting coordinate system.

  Example:

  ```
  ...
  ```

  This works like `Contex.ContinuousLinearScale` with a few notable
  differences:

  - `log_base` is the logarithm base. Usually 2.
  - `negative_numbers` controls how negative numbers are represented.
     It can be:
    * `:mask`: always return 0
    * `:clip`: will map all negative values a very small positive one
    * `:sym`: logarithms are drawn symmetrically, that is, the log of a
      number *n* with n < 0 is -log(abs(n))
  - `linear_range` is a range where results are not logarithmical

  """

  alias __MODULE__
  alias Contex.ScaleUtils

  defstruct [
    :domain,
    :range,
    :log_base_fn,
    :negative_numbers,
    :linear_range,
    :custom_tick_formatter,

    # These are compouted automagically
    :nice_domain,
    :interval_count,
    :interval_size,
    :display_decimals
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new scale with defaults.



  """
  @spec new :: Contex.ContinuousLogScale.t()
  def new(options \\ []) do
    dom =
      Keyword.get(options, :domain, {0.0, 1.0})
      |> ScaleUtils.validate_range(":domain")

    rng =
      Keyword.get(options, :range, nil)
      |> ScaleUtils.validate_range_nil(":range")

    ic = Keyword.get(options, :interval_count, 10)

    lb =
      Keyword.get(options, :log_base, :base_2)
      |> ScaleUtils.validate_option(":log_base", [:base_2, :base_e, :base_10])

    neg_num =
      Keyword.get(options, :negative_numbers, :clip)
      |> ScaleUtils.validate_option(":negative_numbers", [:clip, :mask, :sym])

    lin_rng = Keyword.get(options, :linear_range, nil)

    log_base_fn =
      case lb do
        :base_2 -> &:math.log2/1
        :base_e -> &:math.log/1
        :base_10 -> &:math.log10/1
      end

    %ContinuousLogScale{
      domain: dom,
      nice_domain: nil,
      range: rng,
      interval_count: ic,
      interval_size: nil,
      display_decimals: nil,
      custom_tick_formatter: nil,
      log_base_fn: log_base_fn,
      negative_numbers: neg_num,
      linear_range: lin_rng
    }
    |> nice()
  end

  def nice(%ContinuousLogScale{domain: {min_d, max_d}, interval_count: interval_count} = c) do
    %{
      nice_domain: nice_domain,
      interval_size: rounded_interval_size,
      interval_count: adjusted_interval_count,
      display_decimals: display_decimals
    } =
      ScaleUtils.compute_nice_settings(
        min_d,
        max_d,
        interval_count
      )

    %{
      c
      | nice_domain: nice_domain,
        interval_size: rounded_interval_size,
        interval_count: adjusted_interval_count,
        display_decimals: display_decimals
    }
  end

  @doc """
  Translates a value into its logarithm,
  given the mode and an optional linear part.
  """
  @spec log_value(number(), function(), :clip | :mask | :sym, float()) :: any
  def log_value(v, fn_exp, mode, lin) when is_number(v) or is_float(lin) or is_nil(lin) do
    is_lin_area =
      case lin do
        nil -> false
        _ -> abs(v) < lin
      end

    # IO.puts("#{inspect({v, mode, is_lin_area, v > 0})}")

    case {mode, is_lin_area, v > 0} do
      {:mask, _, false} ->
        0

      {:mask, true, true} ->
        v

      {:mask, false, true} ->
        fn_exp.(v)

      {:clip, _, false} ->
        0

      {:clip, true, true} ->
        v

      {:clip, false, true} ->
        fn_exp.(v)

      {:sym, true, _} ->
        v

      {:sym, false, false} ->
        if v < 0 do
          0 - fn_exp.(-v)
        else
          0
        end

      {:sym, false, true} ->
        fn_exp.(v)
    end
  end

  def get_domain_to_range_function(
        %ContinuousLogScale{
          domain: {min_d, max_d},
          range: {min_r, max_r},
          log_base_fn: log_base_fn,
          negative_numbers: neg_num,
          linear_range: lin_rng
        } = _scale
      ) do
    log_fn = fn v -> log_value(v, log_base_fn, neg_num, lin_rng) end

    min_log_d = log_fn.(min_d)
    max_log_d = log_fn.(max_d)
    width_d = max_log_d - min_log_d
    width_r = max_r - min_r

    fn x ->
      log_x = log_fn.(x)
      v = ScaleUtils.rescale_value(log_x, min_log_d, width_d, min_r, width_r)
      # IO.puts("Domain: #{x} -> #{log_x} -> #{v}")
      v
    end
  end

  # ===============================================================
  # Implementation of Contex.Scale

  defimpl Contex.Scale do
    def domain_to_range_fn(%ContinuousLogScale{} = scale),
      do: ContinuousLogScale.get_domain_to_range_function(scale)

    def ticks_domain(%ContinuousLogScale{
          nice_domain: {min_d, _},
          interval_count: interval_count,
          interval_size: interval_size
        })
        when is_number(min_d) and is_number(interval_count) and is_number(interval_size) do
      0..interval_count
      |> Enum.map(fn i -> min_d + i * interval_size end)
    end

    def ticks_domain(_), do: []

    def ticks_range(%ContinuousLogScale{} = scale) do
      transform_func = ContinuousLogScale.get_domain_to_range_function(scale)

      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range(%ContinuousLogScale{} = scale, range_val) do
      transform_func = ContinuousLogScale.get_domain_to_range_function(scale)
      transform_func.(range_val)
    end

    def get_range(%ContinuousLogScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%ContinuousLogScale{} = scale, start, finish)
        when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
    end

    def set_range(%ContinuousLogScale{} = scale, {start, finish})
        when is_number(start) and is_number(finish),
        do: set_range(scale, start, finish)

    def get_formatted_tick(
          %ContinuousLogScale{
            display_decimals: display_decimals,
            custom_tick_formatter: custom_tick_formatter
          },
          tick_val
        ) do
      ScaleUtils.format_tick_text(tick_val, display_decimals, custom_tick_formatter)
    end
  end
end
