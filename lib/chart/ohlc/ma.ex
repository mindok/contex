defmodule Contex.OHLC.MA do
  @moduledoc """
  Moving Average indicator
  """
  import Extructure
  alias Contex.{Dataset, Plot, OHLC, OHLC.Overlayable}

  defstruct dataset: nil,
            period: 14,
            method: :simple,
            apply_to: :close,
            color: "#FF000",
            width: 1

  @type method() :: :simple | :exponential | :weighted
  @type apply_to() :: :open | :high | :low | :close
  @type t() :: %__MODULE__{}

  @spec new(map() | keyword()) :: t()
  def new(args \\ []) do
    struct!(__MODULE__, args)
  end

  @spec init(t(), OHLC.t()) :: t()
  def init(%__MODULE__{} = ma, ohlc) do
    [dataset, accessors] <~ ohlc.mapping
    value_fn = Map.fetch!(accessors, ma.apply_to)

    dataset =
      dataset.data
      |> Stream.map(&{accessors.datetime.(&1), value_fn.(&1)})
      |> generate(ma.method, ma.period)
      |> Dataset.new(["Date", "Average"])

    %{ma | dataset: dataset}
  end

  @spec generate(Enumerable.t(Overlayable.row()), method(), non_neg_integer()) :: [
          Overlayable.row()
        ]
  defp generate(data, method, period)

  defp generate(data, :simple, period) do
    {sma, _, _} =
      Enum.reduce(data, {[], [], 0}, fn row, {rows, subset, count} ->
        {dt, value} = row
        subset = Enum.take([value | subset], period)

        if count >= period do
          average = Enum.sum(subset) / period

          {[{dt, average} | rows], subset, count + 1}
        else
          {rows, subset, count + 1}
        end
      end)

    Enum.reverse(sma)
  end

  defp generate(_data, method, _period) do
    raise "#{inspect(method)} not yet supported"
  end

  @doc false
  @spec lag(t()) :: non_neg_integer()
  def lag(ma) do
    ma.period
  end

  @doc false
  @spec render(t(), Overlayable.RenderConfig.t()) :: [Overlayable.rendered_row()]
  def render(%__MODULE__{dataset: %Dataset{}} = ma, render_config) do
    [domain, x_transform, y_transform] <~ render_config

    dataset =
      Dataset.update_data(ma.dataset, fn data ->
        Enum.filter(data, &OHLC.within_domain?(elem(&1, 0), domain))
      end)

    with true <- !Enum.empty?(dataset.data) || [] do
      options = [
        mapping: %{x_col: "Date", y_cols: ["Average"]},
        stroke_width: "#{Integer.to_string(ma.width)}",
        colour_palette: [ma.color],
        show_x_axis: false,
        show_y_axis: false,
        x_transform: x_transform,
        y_transform: y_transform
      ]

      Plot.new(dataset, Contex.LinePlot, 100, 100, options)
      |> Plot.to_svg()
      |> elem(1)
      |> List.flatten()
      |> Enum.split_while(&(!String.starts_with?(&1, "<path")))
      |> elem(1)
      |> Enum.split_while(&(!String.ends_with?(&1, "</path>")))
      |> then(&(elem(&1, 0) ++ List.wrap(List.first(elem(&1, 1)))))
    end
  end
end

defimpl Contex.OHLC.Overlayable, for: Contex.OHLC.MA do
  alias Contex.OHLC.MA

  def init(ma, ohlc) do
    MA.init(ma, ohlc)
  end

  def lag(ma) do
    MA.lag(ma)
  end

  def render(ma, render_config) do
    MA.render(ma, render_config)
  end
end
