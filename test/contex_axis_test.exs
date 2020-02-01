defmodule ContexAxisTest do
  use ExUnit.Case

  alias Contex.{Axis, ContinuousLinearScale}
  import SweetXml

  defp axis_map(axis) do
    Axis.to_svg(axis)
    |> IO.chardata_to_string()
    |> xpath(~x"/g", 
      transform: ~x"./@transform"s,
      text_anchor: ~x"./@text-anchor"s,
      path: [
        ~x"./path", 
        d: ~x"./@d"s
      ],
      ticks: [
        ~x"./g[@class='exc-tick']"l,
        transform: ~x"./@transform"s,
        line: [
          ~x"./line",
          x2: ~x"./@x2"s,
          y2: ~x"./@y2"s
        ],
        text: [
          ~x"./text",
          x: ~x"./@x"s,
          y: ~x"./@y"s,
          dy: ~x"./@dy"s,
          text: ~x"./text()"s
        ]
      ]
    )
  end

  setup do
    axis = Axis.new("foo", :top)
    %{axis: axis}
  end

  # TODO
  # Seems likes type of value passed as a scale should be validated
  describe "new/1" do
    test "returns an axis struct given (anything for) scale and a valid orientation", %{axis: axis} do
      assert axis.scale == "foo" 
      assert axis.orientation == :top 
    end

    test "raises when given an invalid orientation" do
      assert_raise FunctionClauseError, fn -> Axis.new("foo", :cattywompus) end
    end
  end

  describe "new_top_axis/1" do
    test "creates axis with orientation set to :top", %{axis: axis} do
      axis = %{axis | orientation: :bottom}
      top_axis = Axis.new_top_axis(axis.scale)
      assert top_axis.orientation == :top
    end
  end

  describe "new_left_axis/1" do
    test "creates axis with orientation set to :left", %{axis: axis} do
      left_axis = Axis.new_left_axis(axis.scale)
      assert left_axis.orientation == :left
    end
  end

  describe "new_bottom_axis/1" do
    test "creates axis with orientation set to :bottom", %{axis: axis} do
      bottom_axis = Axis.new_bottom_axis(axis.scale)
      assert bottom_axis.orientation == :bottom
    end
  end

  describe "new_right_axis/1" do
    test "creates axis with orientation set to :right", %{axis: axis} do
      right_axis = Axis.new_right_axis(axis.scale)
      assert right_axis.orientation == :right
    end
  end

  describe "set_offset/1" do
    test "updates the offset", %{axis: axis} do
      axis = Axis.set_offset(axis, 5)
      assert axis.offset == 5
    end
  end

  describe "to_svg(%Axis{orientation: :right})" do
    setup do
      axis = 
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain(0, 1)
        |> Axis.new(:right)
      %{axis_map: axis_map(axis)}
    end

    test "shifts axis properly", %{axis_map: axis_map} do
      assert axis_map.transform == "translate(0, 0)"
    end

    test "sets text-anchor 'start'", %{axis_map: axis_map} do
      assert axis_map.text_anchor == "start"
    end  

    test "positions axis line properly", %{axis_map: axis_map} do
      assert axis_map.path.d == "M6,0.5H0.5V1.5H6"
    end

    test "positions tick marks properly", %{axis_map: axis_map} do
      assert ["(0, 0.5)", "(0, 0.7)", "(0, 0.9)", "(0, 1.1)", "(0, 1.3)", "(0, 1.5)"] ==
        Enum.map(axis_map.ticks, fn tick -> Map.get(tick, :transform) end)
        |> Enum.map(fn tick -> String.trim_leading(tick, "translate") end) 

      assert ["6"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:line, :x2]) end)
        |> Enum.uniq()

      assert ["0.32em"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :dy]) end)
        |> Enum.uniq()

      assert ["0.00", "0.20", "0.40", "0.60", "0.80", "1.00"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :text]) end)
    end
  end

  describe "to_svg(%Axis{orientation: :bottom})" do
    setup do
      axis = 
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain(0, 1)
        |> Axis.new(:bottom)
      %{axis_map: axis_map(axis)}
    end

    test "shifts axis properly", %{axis_map: axis_map} do
      assert axis_map.transform == "translate(0, 0)"
    end

    test "sets text-anchor for to 'middle'", %{axis_map: axis_map} do
      assert axis_map.text_anchor == "middle"
    end

    test "positions axis line properly", %{axis_map: axis_map} do
      assert axis_map.path.d == "M0.5, 6V0.5H1.5V6"
    end

    test "positions tick marks properly", %{axis_map: axis_map} do
      assert ["(0.5,0)", "(0.7,0)", "(0.9,0)", "(1.1,0)", "(1.3,0)", "(1.5,0)"] ==
        Enum.map(axis_map.ticks, fn tick -> Map.get(tick, :transform) end)
        |> Enum.map(fn tick -> String.trim_leading(tick, "translate") end) 

      assert ["6"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:line, :y2]) end)
        |> Enum.uniq()

     assert ["0.71em"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :dy]) end)
        |> Enum.uniq()

      assert ["0.00", "0.20", "0.40", "0.60", "0.80", "1.00"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :text]) end)
    end
  end

  describe "to_svg(%Axis{orientation: :top})" do
    setup do
      axis = 
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain(0, 1)
        |> Axis.new(:top)
      %{axis_map: axis_map(axis)}
    end

    test "does not shift axis", %{axis_map: axis_map} do
      assert axis_map.transform == ""
    end

    test "sets text-anchor for to 'middle'", %{axis_map: axis_map} do
      assert axis_map.text_anchor == "middle"
    end

    test "positions axis line properly", %{axis_map: axis_map} do
      assert axis_map.path.d == "M0.5, -6V0.5H1.5V-6"
    end

    # TODO
    # For top/bottom there's not space between the values;
    test "positions tick marks properly", %{axis_map: axis_map} do
      assert ["(0.5,0)", "(0.7,0)", "(0.9,0)", "(1.1,0)", "(1.3,0)", "(1.5,0)"] ==
        Enum.map(axis_map.ticks, fn tick -> Map.get(tick, :transform) end)
        |> Enum.map(fn tick -> String.trim_leading(tick, "translate") end) 

      assert ["-6"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:line, :y2]) end)
        |> Enum.uniq()

      assert [""] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :dy]) end)
        |> Enum.uniq()

      assert ["0.00", "0.20", "0.40", "0.60", "0.80", "1.00"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :text]) end)
    end
  end

  describe "to_svg(%Axis{orientation: :left})" do
    setup do
      axis = 
        ContinuousLinearScale.new()
        |> ContinuousLinearScale.domain(0, 1)
        |> Axis.new(:left)
      %{axis_map: axis_map(axis)}
    end

    test "does not shift axis", %{axis_map: axis_map} do
      assert axis_map.transform == ""
    end

    test "sets text-anchor to 'end'", %{axis_map: axis_map} do
      assert axis_map.text_anchor == "end"
    end  

    test "positions axis line properly", %{axis_map: axis_map} do
      assert axis_map.path.d == "M-6,0.5H0.5V1.5H-6"
    end

    test "positions tick marks properly", %{axis_map: axis_map} do
      assert ["(0, 0.5)", "(0, 0.7)", "(0, 0.9)", "(0, 1.1)", "(0, 1.3)", "(0, 1.5)"] ==
        Enum.map(axis_map.ticks, fn tick -> Map.get(tick, :transform) end)
        |> Enum.map(fn tick -> String.trim_leading(tick, "translate") end) 

      assert ["-6"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:line, :x2]) end)
        |> Enum.uniq()

      assert ["0.32em"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :dy]) end)
        |> Enum.uniq()

      assert ["0.00", "0.20", "0.40", "0.60", "0.80", "1.00"] ==
        Enum.map(axis_map.ticks, fn tick -> get_in(tick, [:text, :text]) end)
    end
  end

  # Not tested yet because it's not clear how it's used
  @tag :skip
  test "gridlines_to_svg/1" do
  end

end
