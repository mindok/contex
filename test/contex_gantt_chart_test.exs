defmodule ContexGanttChartTest do
  use ExUnit.Case

  alias Contex.{Dataset, GanttChart, Plot}
  import SweetXml

  setup do
    plot =
      Dataset.new([
        {"Category 1", "Task 1", ~N{2019-10-01 10:00:00}, ~N{2019-10-02 10:00:00}, "1_1"},
        {"Category 1", "Task 2", ~N{2019-10-02 10:00:00}, ~N{2019-10-04 10:00:00}, "1_2"},
        {"Category 2", "Task 3", ~N{2019-10-04 10:00:00}, ~N{2019-10-05 10:00:00}, "2_3"},
        {"Category 2", "Task 4", ~N{2019-10-06 10:00:00}, ~N{2019-10-08 10:00:00}, "2_4"}
      ],
        ["Category", "Task", "Start", "End", "Task ID"]
      )
      |> GanttChart.new()

     dataset_maps =
      Dataset.new([
        %{category: "Category 1", task: "Task 1", start: ~N{2019-10-01 10:00:00}, finish: ~N{2019-10-02 10:00:00}},
        %{category: "Category 1", task: "Task 2", start: ~N{2019-10-02 10:00:00}, finish: ~N{2019-10-04 10:00:00}},
        %{category: "Category 2", task: "Task 3", start: ~N{2019-10-04 10:00:00}, finish: ~N{2019-10-05 10:00:00}},
        %{category: "Category 2", task: "Task 4", start: ~N{2019-10-06 10:00:00}, finish: ~N{2019-10-08 10:00:00}}
        ]
      )
  %{plot: plot, dataset_maps: dataset_maps}
  end

  # TODO
  # Why is width/height set here and not in defaults/1?
  describe "new/2" do
    test "returns a GanttChart struct with defaults", %{plot: plot} do
      assert plot.width == 100
      assert plot.height == 100
    end

    test "given data from a map and a series mapping, returns GanttChart struct accordingly", %{dataset_maps: dataset_maps} do
      plot =
        dataset_maps
        |> GanttChart.new(series_mapping: %{
          category_col: :category,
          task_col: :task,
          start_col: :start,
          finish_col: :finish
        }
        )

      assert plot.padding == 2
      assert plot.show_task_labels == true
      assert plot.category_col == :category
      assert plot.task_col == :task
      assert plot.interval_cols == {:start, :finish}
    end

    test "Raises if no series is passed with map data", %{dataset_maps: dataset_maps} do
      assert_raise(
        ArgumentError,
        "Invalid series definition; series_mapping must be a map with category_col, task_col, start_col and finish_col keys.",
        fn -> GanttChart.new(dataset_maps, series_mapping: %{x_col: :category}) end
        )
    end

    test "Raises if invalid series is passed with map data", %{dataset_maps: dataset_maps} do
      assert_raise(
        ArgumentError,
        "Series mapping must be provided with map data.",
        fn -> GanttChart.new(dataset_maps) end
        )
    end
  end

  describe "defaults/1" do
    test "returns a GanttChart struct with default properties", %{plot: plot} do
      assert plot.padding == 2
      assert plot.show_task_labels == true
      assert plot.category_col == "Category"
      assert plot.task_col == "Task"
      assert plot.interval_cols == {"Start", "End"}
    end
  end

  describe "show_task_labels/2" do
    test "sets the show task label switch", %{plot: plot} do
      plot = GanttChart.show_task_labels(plot, false)
      assert plot.show_task_labels == false
    end
  end

  describe "set_category_task_cols/3" do
    test "sets the category and task columns", %{plot: plot} do
      plot = GanttChart.set_category_task_cols(plot, "Task", "Category")
      assert plot.category_col == "Task"
      assert plot.task_col == "Category"
    end

    test "raises when given column is not in the dataset", %{plot: plot} do
      assert_raise(
        RuntimeError,
        "Column \"Wrong Series\" not in the dataset.",
        fn ->
          GanttChart.set_category_task_cols(plot, "Wrong Series", "Task")
        end
      )
    end
  end

  describe "set_task_interval_cols/2" do
    test "sets the interval columns' values", %{plot: plot} do
      plot = GanttChart.set_task_interval_cols(plot, {"End", "Start"})
      assert plot.interval_cols == {"End", "Start"}
    end

    test "raises when given column is not in the dataset", %{plot: plot} do
      assert_raise(
        RuntimeError,
        "Column \"Wrong Series\" not in the dataset.",
        fn ->
          GanttChart.set_task_interval_cols(plot, {"End", "Wrong Series"})
        end
      )
    end
  end

  describe "event_handler/2" do
    test "sets the Phoenix event handler", %{plot: plot} do
      plot = GanttChart.event_handler(plot, "clicked")
      assert plot.phx_event_handler == "clicked"
    end
  end

  describe "set_id_col/2" do
    test "sets the id column", %{plot: plot} do
      plot = GanttChart.set_id_col(plot, "Task ID")
      assert plot.id_col == "Task ID"
    end

    test "raises when given column is not in the dataset", %{plot: plot} do
      assert_raise(
        RuntimeError,
        "Column \"Wrong Series\" not in the dataset.",
        fn ->
          GanttChart.set_id_col(plot, "Wrong Series")
        end
      )
    end
  end

  describe "to_svg/1" do
    defp plot_iodata_to_map(plot_iodata) do
      IO.chardata_to_string(plot_iodata)
      |> xpath(~x"/svg/g/g/rect"l, [
        x: ~x"./@x"s,
        y: ~x"./@y"s,
        width: ~x"./@width"s,
        height: ~x"./@height"s
      ])
    end

    defp label_iodata_to_map(plot_iodata) do
      IO.chardata_to_string(plot_iodata)
      |> xpath(~x"/svg/g/g[not(@class)]/text"l, [
        label: ~x"./text()"s
      ])
    end

    # Axis and legend svg not tested as they are for practical purposes handled
    # by Contex.Axis and Context.Legend, tested separately
    test "returns properly constructed chart", %{plot: plot} do
      rects_map =
        Plot.new(200, 200, plot)
        |> Plot.to_svg()
        |> elem(1)
        |> plot_iodata_to_map()

      string_to_rounded_float = fn value ->
        Float.parse(value)
        |> elem(0)
        |> Float.round(3)
      end

      assert [
        [28.0, 15.0, 6.25, 1.0],
        [28.0, 30.0, 21.25, 31.0],
        [28.0, 15.0, 51.25, 61.0],
        [28.0, 30.0, 81.25, 91.0]
      ]

       ==

      Stream.map(rects_map, &Enum.unzip/1)
      |> Stream.map(fn value ->
           elem(value, 1)
           end
         )
      |> Enum.map(fn value ->
           Enum.map(value, string_to_rounded_float)
           end
         )

      labels =
        Plot.new(200, 200, plot)
        |> Plot.to_svg()
        |> elem(1)
        |> label_iodata_to_map()
        |> Enum.map(&(Map.get(&1, :label)))

      assert labels == ["Task 1", "Task 2", "Task 3", "Task 4"]
    end

    test "generates equivalent output with map data", %{plot: plot, dataset_maps: dataset_maps} do
      map_plot_svg =
        dataset_maps
        |> Plot.new(GanttChart, 200, 200, series_mapping: %{
          category_col: :category,
          task_col: :task,
          start_col: :start,
          finish_col: :finish
        })
        |> Plot.to_svg()

      assert map_plot_svg ==
        plot.dataset
        |> Plot.new(GanttChart, 200, 200)
        |> Plot.to_svg()
    end
  end
end
