defprotocol Contex.OHLC.Overlayable do
  @moduledoc """
  Provides a common interface for charts that can be overlaid
  over an OHLC chart.
  """
  alias Contex.OHLC
  alias Contex.OHLC.Overlayable

  @type t() :: term()
  @type row() :: list()
  @type ohlc_options() :: keyword()
  @type rendered_row() :: list()

  @doc """
  Initializes overlay data base on the provided OHLC
  """
  @spec init(t(), OHLC.t()) :: t()
  def init(overlay, ohlc)

  @doc """
  Returns the interval count it lags behind the present.
  """
  @spec lag(t()) :: non_neg_integer()
  def lag(overlay)

  @doc """
  Renders overlay.
  """
  @spec render(t(), Overlayable.RenderConfig.t()) :: [rendered_row()]
  def render(overlay, render_config)
end

defmodule Contex.OHLC.Overlayable.RenderConfig do
  alias Contex.OHLC

  @enforce_keys [:domain, :x_transform, :y_transform]
  defstruct @enforce_keys

  @type t() :: %__MODULE__{}

  @spec new(OHLC.t()) :: t()
  def new(ohlc) do
    struct!(
      __MODULE__,
      domain: ohlc.x_scale.domain,
      x_transform: ohlc.transforms.x,
      y_transform: ohlc.transforms.y
    )
  end
end
