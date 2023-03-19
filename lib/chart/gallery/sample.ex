defmodule Contex.Gallery.Sample do
  alias Contex.Plot

  @moduledoc """
  Renders plots to be used in ExDocs and tests.

  The idea is that each graph is displayed along its
  source code, so it's very easy to spot what is what.
  To shortern the source code displayed, though, aliases
  are imported but not shown.
  """

  @doc """
  Adds a graph to a documentation block.

  Usage:

      import Contex.Gallery.Sample, only: [graph: 1]

      graph(title: "A stacked sample",
            file: "bar_charts_log_stacked.sample",
            info: "Some Markdown description")

  If there are rendering errors, a message is printed
  on stdout and the full text of the error is shown
  on the docs. We don't want this to break, as docs
  are generated at compile time, so if they break, your
  code does not compile!

  """

  def graph(options \\ []) do
    path = Keyword.get(options, :path, "lib/chart/gallery")
    file = Keyword.get(options, :file, nil)
    aliases = Keyword.get(options, :aliases, "00_aliases.sample")
    title = Keyword.get(options, :title, "")
    bgcolor = Keyword.get(options, :bgcolor, "#fff")
    extra_info_text = Keyword.get(options, :info, "")

    case safely_evaluate_svg(["#{path}/#{aliases}", "#{path}/#{file}"]) do
      {:ok, source_code, svg, time} ->
        """
        # #{title}

        #{extra_info_text}

        __Rendering took #{time} ms - Size: #{String.length(svg) / 1000} Kb__


        ```
        #{source_code}
        ```

        #{encode_svg(svg, bgcolor)}


        """

      {:error, error_text, filename, code_run, time} ->
        with IO.puts("Error processing #{filename} - see generated docs") do
          """
          # Error: #{title}

          ```
          #{code_run}
          ```

          Raised error:

          ```
          #{error_text}
          ```


          __Rendering took #{time} ms__
          """
        end
    end
  end

  defp uid(), do: make_ref() |> inspect() |> String.slice(11, 99) |> String.replace(">", "")

  @doc """
  Will try and evaluate a set of files, by sticking them  in order
  one after the other.

  If all goes well, it will return the SVG generated and
  how long execution took.

  If there are any errors, it will return the error, the complete
  source code that was evaluated (with includes) and how long
  execution took in ms.
  """
  def safely_evaluate_svg(files) do
    code_to_evaluate =
      files
      |> Enum.map(fn f ->
        {:ok, code} = File.read(f)

        """
        ## Source: #{f}

        #{code}

        """
      end)
      |> Enum.join()

    filename =
      files
      |> List.last()

    {:ok, source} =
      filename
      |> File.read()

    timer = mkTimer()

    try do
      {plot, _} = Code.eval_string(code_to_evaluate)
      {:safe, svg_list} = Plot.to_svg(plot)
      {:ok, source, List.to_string(svg_list), timer.()}
    rescue
      e ->
        {:error, Exception.format(:error, e, __STACKTRACE__), filename, code_to_evaluate,
         timer.()}
    end
  end

  @doc """
  Encodes a div for our SVG.

  Unfortunately, we need to split it into multiple
  lines, as ExDoc is veeeeery slow with long
  text lines.

  It also complains of SVG code being improperly formatted,
  and breaks the page.

  So we encode the SVG as one long JS line, and then
  stick it into the container DIV we just created.

  """
  def encode_svg(svg, bgcolor) do
    encoded_svg = URI.encode(svg)

    chunked_svg =
      encoded_svg
      |> String.codepoints()
      |> Enum.chunk_every(50)
      |> Enum.map(&Enum.join/1)
      |> Enum.map(fn c -> "\"#{c}\"" end)
      |> Enum.join(" + \n")

    block_id = uid()

    """

    <div id="#{block_id}" style="background: #{bgcolor}">
    </div>


    <script>
    document.getElementById('#{block_id}').innerHTML =  decodeURI( #{chunked_svg} );

    </script>
    """
  end

  @doc """
  Returns a timer function.

  By calling it, we get the number of elapsed milliseconds
  since the function was created.

  """

  def mkTimer() do
    t0 = :erlang.monotonic_time(:millisecond)
    fn -> :erlang.monotonic_time(:millisecond) - t0 end
  end
end
