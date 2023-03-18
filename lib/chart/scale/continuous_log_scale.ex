defmodule Contex.ContinuousLogScale do
  @moduledoc """
  A logarithmic scale to map continuous numeric data to a plotting coordinate system.

  This works like `Contex.ContinuousLinearScale`, and the
  settings are given as keywords.

        ContinuousLogScale.new(
              domain: {0, 100},
              tick_positions: [0, 5, 10, 15, 30, 60,  120,  240, 480, 960],
              log_base: :base_10,
              negative_numbers: :mask,
              linear_range: 1
            )

  **Logarithm**

  - `log_base` is the logarithm base. Defaults to 2. Can be
     set to `:base_2`, `:base_e` or  `:base_10`.
  - `negative_numbers` controls how negative numbers are represented.
     It can be:
    * `:mask`: always return 0
    * `:clip`: always returns 0
    * `:sym`: logarithms are drawn symmetrically, that is, the log of a
      number *n* when n < 0 is -log(abs(n))
  - `linear_range` is a range -if any- where results are not logarithmical

  **Data domain**

  Unfortunately, a domain must be given for all custom scales.
  To make your life easier, you can either:

  - `domain: {0, 27}` will set an explicit domain, or
  - `dataset` and `axis` let you specify a Dataset and one or a list of axes,
    and the domain will be computed out of them all.

  **Ticks**

  - `interval_count` divides the interval in `n` linear slices, or
  - `tick_positions` can receive a list of explicit possible
    ticks, that will be displayed ony if they are within the domain
    area.
  - `custom_tick_formatter` is a function to be applied to the
    ticks.

  """

  alias __MODULE__
  alias Contex.ScaleUtils
  alias Contex.Dataset

  defstruct [
    :domain,
    :range,
    :log_base_fn,
    :negative_numbers,
    :linear_range,
    :custom_tick_formatter,
    :tick_positions,
    :interval_count,

    # These are compouted automagically
    :nice_domain,
    :display_decimals
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new scale with defaults.



  """
  @spec new :: Contex.ContinuousLogScale.t()
  def new(options \\ []) do
    dom =
      get_domain(
        Keyword.get(options, :domain, :notfound),
        Keyword.get(options, :dataset, :notfound),
        Keyword.get(options, :axis, :notfound)
      )
      |> ScaleUtils.validate_range(":domain")

    rng =
      Keyword.get(options, :range, nil)
      |> ScaleUtils.validate_range_nil(":range")

    ic = Keyword.get(options, :interval_count, 10)

    is = Keyword.get(options, :tick_positions, nil)

    lb =
      Keyword.get(options, :log_base, :base_2)
      |> ScaleUtils.validate_option(":log_base", [:base_2, :base_e, :base_10])

    neg_num =
      Keyword.get(options, :negative_numbers, :clip)
      |> ScaleUtils.validate_option(":negative_numbers", [:clip, :mask, :sym])

    lin_rng = Keyword.get(options, :linear_range, nil)

    ctf = Keyword.get(options, :custom_tick_formatter, nil)

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
      tick_positions: is,
      interval_count: ic,
      display_decimals: nil,
      custom_tick_formatter: ctf,
      log_base_fn: log_base_fn,
      negative_numbers: neg_num,
      linear_range: lin_rng
    }
    |> nice()
  end

  @doc """
  Fixes inconsistencies and scales.
  """
  @spec nice(Contex.ContinuousLogScale.t()) :: Contex.ContinuousLogScale.t()
  def nice(
        %ContinuousLogScale{
          domain: {min_d, max_d},
          interval_count: interval_count,
          tick_positions: tick_positions
        } = c
      ) do
    %{
      nice_domain: nice_domain,
      ticks: computed_ticks,
      display_decimals: display_decimals
    } =
      ScaleUtils.compute_nice_settings(
        min_d,
        max_d,
        tick_positions,
        interval_count
      )

    %{
      c
      | nice_domain: nice_domain,
        tick_positions: computed_ticks,
        display_decimals: display_decimals
    }
  end

  @spec get_domain(:notfound | {any, any}, any, any) :: {number(), number()}
  @doc """
  Computes the correct domain {a, b}.

  - If it is explicitly passed, we use it.
  - If there is a dataset and a column or a list of columns, we use that
  - If all else fails, we use {0, 1}
  """
  def get_domain(:notfound, %Dataset{} = requested_dataset, requested_columns)
      when is_list(requested_columns) do
    all_ranges =
      requested_columns
      |> Enum.map(fn c -> Dataset.column_extents(requested_dataset, c) end)

    minimum =
      all_ranges
      |> Enum.map(fn {min, _} -> min end)
      |> Enum.min()

    maximum =
      all_ranges
      |> Enum.map(fn {_, max} -> max end)
      |> Enum.max()

    {minimum, maximum}
  end

  def get_domain(:notfound, %Dataset{} = requested_dataset, requested_column),
    do: get_domain(:notfound, requested_dataset, [requested_column])

  def get_domain({_a, _b} = requested_domain, _requested_dataset, _requested_column),
    do: requested_domain

  def get_domain(_, _, _), do: {0, 1}

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

  @spec get_domain_to_range_function(Contex.ContinuousLogScale.t()) :: (number -> float)
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
    @spec domain_to_range_fn(Contex.ContinuousLogScale.t()) :: (number -> float)
    def domain_to_range_fn(%ContinuousLogScale{} = scale),
      do: ContinuousLogScale.get_domain_to_range_function(scale)

    @spec ticks_domain(Contex.ContinuousLogScale.t()) :: list(number)
    def ticks_domain(%ContinuousLogScale{
          tick_positions: tick_positions
        }) do
      tick_positions
    end

    def ticks_domain(_), do: []

    @spec ticks_range(Contex.ContinuousLogScale.t()) :: list(number)
    def ticks_range(%ContinuousLogScale{} = scale) do
      transform_func = ContinuousLogScale.get_domain_to_range_function(scale)

      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    @spec domain_to_range(Contex.ContinuousLogScale.t(), number) :: float
    def domain_to_range(%ContinuousLogScale{} = scale, range_val) do
      transform_func = ContinuousLogScale.get_domain_to_range_function(scale)
      transform_func.(range_val)
    end

    @spec get_range(Contex.ContinuousLogScale.t()) :: {number, number}
    def get_range(%ContinuousLogScale{range: {min_r, max_r}}), do: {min_r, max_r}

    @spec set_range(Contex.ContinuousLogScale.t(), number, number) ::
            Contex.ContinuousLogScale.t()
    def set_range(%ContinuousLogScale{} = scale, start, finish)
        when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
    end

    @spec set_range(Contex.ContinuousLogScale.t(), {number, number}) ::
            Contex.ContinuousLogScale.t()
    def set_range(%ContinuousLogScale{} = scale, {start, finish})
        when is_number(start) and is_number(finish),
        do: set_range(scale, start, finish)

    @spec get_formatted_tick(Contex.ContinuousLogScale.t(), any) :: binary
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
