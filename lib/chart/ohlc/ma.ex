defmodule Contex.OHLC.MA do
  @moduledoc """
  Moving Average indicator
  """
  import Extructure
  alias Contex.{Dataset, Plot, OHLC, OHLC.Overlayable}

  defstruct dataset: nil,
            period: 14,
            shift: 0,
            method: :simple,
            apply_to: :close,
            color: "#FF000"

  @type method() :: :simple | :exponential | :smoothed | :weighted
  @type apply_to() :: :open | :high | :low | :close
  @type t() :: %__MODULE__{}

  @spec new(map() | keyword()) :: t()
  def new(args \\ []) do
    struct!(__MODULE__, args)
  end

  @spec init(t(), OHLC.t()) :: t()
  def init(%__MODULE__{} = ma, ohlc) do
    [dataset, accessors] <~ ohlc.mapping

    dataset =
      dataset.data
      |> Enum.map(&{accessors.datetime.(&1), accessors.close.(&1)})
      |> Dataset.new(["Date", "Close"])

    %{ma | dataset: dataset}
  end

  @doc false
  @spec render(t(), Overlayable.RenderConfig.t()) :: [Overlayable.rendered_row()]
  def render(%__MODULE__{dataset: %Dataset{}} = ma, render_config) do
    dataset =
      Dataset.update_data(ma.dataset, fn data ->
        Enum.filter(data, &OHLC.within_domain?(elem(&1, 0), render_config.domain))
      end)

    options = [
      mapping: %{x_col: "Date", y_cols: ["Close"]},
      smoothed: false,
      stroke_width: "1",
      colour_palette: ["ff9838"],
      show_x_axis: false,
      show_y_axis: false,
      x_transform: render_config.x_transform,
      y_transform: render_config.y_transform
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

defimpl Contex.OHLC.Overlayable, for: Contex.OHLC.MA do
  alias Contex.OHLC.MA

  def init(ma, ohlc) do
    MA.init(ma, ohlc)
  end

  def render(ma, ohlc) do
    MA.render(ma, ohlc)
  end
end
