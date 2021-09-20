defmodule ContinuousLinearScaleTest do
  use ExUnit.Case

  alias Contex.ContinuousLinearScale

  describe "new/0" do
    test "returns a ContinuousLinearScale struct with default values" do
      scale = ContinuousLinearScale.new()

      assert scale.range == {0.0, 1.0}
      assert scale.interval_count == 10
      assert scale.display_decimals == nil
    end
  end

  describe "domain/2" do
    test "returns a ContinuousLinearScale" do
      scale =
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain([1.2, 2.4, 0.5, 0.2, 2.8])

      assert scale.domain == {0.2, 2.8}
    end

    test "returns a ContinuousLinearScale for data with small values (largest_value <= 0.0001)" do
      scale =
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain([0.0, 0.0001, 0.0, 0.0001, 0.0])

      assert scale.domain == {0.0, 0.0001}
    end
  end
end
