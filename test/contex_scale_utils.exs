defmodule ScaleUtilsTest do
  use ExUnit.Case

  alias Contex.ScaleUtils

  describe "new/0" do
    test "returns a ContinuousLinearScale struct with default values" do
      scale = ContinuousLogScale.new()

      assert scale.range == {0.0, 1.0}
      assert scale.interval_count == 10
      assert scale.display_decimals == nil
    end
  end
end
