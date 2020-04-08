defmodule Contex.OrdinalScale do
  @moduledoc """
  An ordinal scale to map discrete values (text or numeric) to a plotting coordinate system.

  An ordinal scale is commonly used for the category axis in barcharts. It has to be able
  to generate the centre-point of the bar (e.g. for tick annotations) as well as the
  available width the bar or bar-group has to fill.

  In order to do that the ordinal scale requires a 'padding' option to be set (defaults to 0.5 in the scale)
  that defines the gaps between the bars / categories. The ordinal scale has two mapping functions for
  the data domain to the plotting range. One returns the centre point (`range_to_domain_fn`) and one
  returns the "band" the category can occupy (`domain_to_range_band_fn`).

  An `OrdinalScale` is initialised with a list of values which represent the categories. The scale generates
  a tick for each value in that list.

  Typical usage of this scale would be as follows:

      iex> category_scale
      ...> = Contex.OrdinalScale.new(["Hippo", "Turtle", "Rabbit"])
      ...> |> Contex.Scale.set_range(0.0, 9.0)
      ...> |> Contex.OrdinalScale.padding(2)
      ...> category_scale.domain_to_range_fn.("Turtle")
      4.5
      iex> category_scale.domain_to_range_band_fn.("Hippo")
      {1.0, 2.0}
      iex> category_scale.domain_to_range_band_fn.("Turtle")
      {4.0, 5.0}
  """
  alias __MODULE__

  defstruct [
    :domain,
    :range,
    :padding,
    :domain_to_range_fn,
    :range_to_domain_fn,
    :domain_to_range_band_fn
  ]

  @type t() :: %__MODULE__{}

  @doc """
  Creates a new ordinal scale.
  """
  @spec new(list()) :: Contex.OrdinalScale.t()
  def new(domain) when is_list(domain) do
    %OrdinalScale{domain: domain, padding: 0.5}
  end

  @doc """
  Updates the domain data for the scale.
  """
  @spec domain(Contex.OrdinalScale.t(), list()) :: Contex.OrdinalScale.t()
  def domain(%OrdinalScale{} = ordinal_scale, data) when is_list(data) do
    %{ordinal_scale | domain: data}
    |> update_transform_funcs()
  end

  @doc """
  Sets the padding between the categories for the scale.

  Defaults to 0.5.

  Defined in terms of plotting coordinates.

  *Note* that if the padding is greater than the calculated width of each category
  you might get strange effects (e.g. the end of a band being before the beginning)
  """
  def padding(%OrdinalScale{} = scale, padding) when is_number(padding) do
    # We need to update the transform functions if we change the padding as the band calculations need it
    %{scale | padding: padding}
    |> update_transform_funcs()
  end

  @doc false
  def update_transform_funcs(
        %OrdinalScale{domain: domain, range: {start_r, end_r}, padding: padding} = scale
      )
      when is_list(domain) and is_number(start_r) and is_number(end_r) and is_number(padding) do
    domain_count = Kernel.length(domain)
    range_width = end_r - start_r

    item_width =
      case domain_count do
        0 -> 0.0
        _ -> range_width / domain_count
      end

    flip_padding =
      case start_r < end_r do
        true -> 1.0
        _ -> -1.0
      end

    # Returns centre point of bucket
    domain_to_range_fn = fn domain_val ->
      case Enum.find_index(domain, fn x -> x == domain_val end) do
        nil ->
          start_r

        index ->
          start_r + item_width / 2.0 + index * item_width
      end
    end

    domain_to_range_band_fn = fn domain_val ->
      case Enum.find_index(domain, fn x -> x == domain_val end) do
        nil ->
          {start_r, start_r}

        index ->
          band_start = start_r + flip_padding * padding / 2.0 + index * item_width
          band_end = start_r + (index + 1) * item_width - flip_padding * padding / 2.0
          {band_start, band_end}
      end
    end

    range_to_domain_fn =
      case range_width do
        0 ->
          fn -> "" end

        _ ->
          fn range_val ->
            case domain_count do
              0 ->
                ""

              _ ->
                bucket_index = Kernel.trunc((range_val - start_r) / item_width)
                Enum.at(domain, bucket_index)
            end
          end
      end

    %{
      scale
      | domain_to_range_fn: domain_to_range_fn,
        range_to_domain_fn: range_to_domain_fn,
        domain_to_range_band_fn: domain_to_range_band_fn
    }
  end

  def update_transform_funcs(%OrdinalScale{} = scale), do: scale

  @doc """
  Returns the band for the nominated category in terms of plotting coordinate system.

  If the category isn't found, the start of the plotting range is returned.
  """
  @spec get_band(Contex.OrdinalScale.t(), any) :: {number(), number()}
  def get_band(%OrdinalScale{domain_to_range_band_fn: domain_to_range_band_fn}, domain_value)
      when is_function(domain_to_range_band_fn) do
    domain_to_range_band_fn.(domain_value)
  end

  defimpl Contex.Scale do
    def ticks_domain(%OrdinalScale{domain: domain}), do: domain

    def ticks_range(%OrdinalScale{domain_to_range_fn: transform_func} = scale)
        when is_function(transform_func) do
      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range_fn(%OrdinalScale{domain_to_range_fn: domain_to_range_fn}),
      do: domain_to_range_fn

    def domain_to_range(%OrdinalScale{domain_to_range_fn: transform_func}, range_val)
        when is_function(transform_func) do
      transform_func.(range_val)
    end

    def get_range(%OrdinalScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%OrdinalScale{} = scale, start, finish)
        when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
      |> OrdinalScale.update_transform_funcs()
    end

    def set_range(%OrdinalScale{} = scale, {start, finish})
        when is_number(start) and is_number(finish),
        do: set_range(scale, start, finish)

    def get_formatted_tick(_, tick_val), do: tick_val
  end
end
