defmodule Contex.OrdinalScale do
  alias __MODULE__

  defstruct [:domain, :range, :padding, :domain_to_range_fn, :range_to_domain_fn, :domain_to_range_band_fn]

  def new(domain) when is_list(domain) do
    %OrdinalScale{domain: domain, padding: 0.5}
  end

  def domain(%OrdinalScale{} = scale, data) when is_list(data) do
    %{scale | domain: data}
    |> update_transform_funcs
  end

  def padding(%OrdinalScale{} = scale, padding) when is_number(padding) do
    # We need to update the transform functions if we change the padding as the band calculations need it
    %{scale | padding: padding}
    |> update_transform_funcs
  end

  def update_transform_funcs(%OrdinalScale{domain: domain, range: {start_r, end_r}, padding: padding} = scale)
  when is_list(domain) and is_number(start_r) and is_number(end_r) and is_number(padding)
    do

    domain_count = Kernel.length(domain)
    range_width = end_r - start_r
    item_width = case domain_count do
      0 -> 0.0
      _ -> range_width / domain_count
    end

    flip_padding = case start_r < end_r do
      true -> 1.0
      _ -> -1.0
    end


    # Returns centre point of bucket
    domain_to_range_fn =
      fn domain_val ->
        case Enum.find_index(domain, fn x -> x == domain_val end) do
          nil -> start_r
          index ->
            start_r + (item_width / 2.0) + (index * item_width)
        end
      end

    domain_to_range_band_fn =
    fn domain_val ->
      case Enum.find_index(domain, fn x -> x == domain_val end) do
        nil -> {start_r, start_r}
        index ->
          band_start = start_r + (flip_padding * padding / 2.0) + (index * item_width)
          band_end = start_r  + ((index + 1) * item_width) - (flip_padding * padding / 2.0)
          {band_start, band_end}
      end
    end


    range_to_domain_fn = case range_width do
    0 -> fn -> "" end
    _ ->
      fn range_val ->
        case domain_count do
          0 -> ""
          _ ->
            bucket_index = Kernel.trunc((range_val - start_r) / item_width)
            Enum.at(domain, bucket_index)
        end
      end
    end

    %{scale | domain_to_range_fn: domain_to_range_fn, range_to_domain_fn: range_to_domain_fn, domain_to_range_band_fn: domain_to_range_band_fn}
    end
  def update_transform_funcs(%OrdinalScale{} = scale), do: scale

  def get_band(%OrdinalScale{domain_to_range_band_fn: domain_to_range_band_fn}, domain_value)
    when is_function(domain_to_range_band_fn) do
      domain_to_range_band_fn.(domain_value)
  end

  defimpl Contex.Scale do
    @spec ticks_domain(Contex.OrdinalScale.t()) :: any
    def ticks_domain(%OrdinalScale{domain: domain}), do: domain

    def ticks_range(%OrdinalScale{domain_to_range_fn: transform_func} = scale) when is_function(transform_func) do
      ticks_domain(scale)
      |> Enum.map(transform_func)
    end

    def domain_to_range_fn(%OrdinalScale{domain_to_range_fn: domain_to_range_fn}), do: domain_to_range_fn

    def domain_to_range(%OrdinalScale{domain_to_range_fn: transform_func}, range_val) when is_function(transform_func) do
      transform_func.(range_val)
    end

    def get_range(%OrdinalScale{range: {min_r, max_r}}), do: {min_r, max_r}

    def set_range(%OrdinalScale{} = scale, start, finish) when is_number(start) and is_number(finish) do
      %{scale | range: {start, finish}}
      |> OrdinalScale.update_transform_funcs
    end
    def set_range(%OrdinalScale{} = scale, {start, finish}) when is_number(start) and is_number(finish), do: set_range(scale, start, finish)

    def get_formatted_tick(_, tick_val), do: tick_val
  end
end
