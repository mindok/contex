defmodule ContexAxisTest do
  use ExUnit.Case

  alias Contex.ContinuousLinearScale
  alias Contex.Scale

  describe "Basic scale tests" do
    test "Crashing bug with round domain range" do
      scale =
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain(1.2, 2.2)
        |> Scale.set_range(0.0, 1.0)

      assert scale.interval_size == 0.2
    end
  end
end
