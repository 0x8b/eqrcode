defmodule EQRCode.SVG do
  @moduledoc """
  Render the QR Code matrix in SVG format

  ```elixir
  qr_code_content
  |> EQRCode.encode()
  |> EQRCode.svg(color: "#cc6600", width: 300)
  ```

  You can specify the following attributes of the QR code:

  * `background_color`: In hexadecimal format or `:transparent`. The default is `#FFF`
  * `color`: In hexadecimal format. The default is `#000`
  * `width`: The width of the QR code in pixel. Without the width attribute, the QR code size will be dynamically generated based on the input string.
  * `viewbox`: When set to `true`, the SVG element will specify its height and width using `viewBox`, instead of explicit `height` and `width` tags.

  Default options are `[color: "#000", background_color: "#FFF"]`.

  """

  alias EQRCode.Matrix

  @doc """
  Return the SVG format of the QR Code
  """
  @spec svg(Matrix.t(), map() | Keyword.t()) :: String.t()
  def svg(%Matrix{matrix: matrix} = m, options \\ []) do
    options = options |> Enum.map(& &1)
    matrix_size = Matrix.size(m)
    svg_options = options |> Map.new() |> set_svg_options(matrix_size)
    dimension = matrix_size * svg_options[:module_size]

    xml_tag = ~s(<?xml version="1.0" standalone="yes"?>)
    viewbox_attr = ~s(viewBox="0 0 #{matrix_size} #{matrix_size}")

    dimension_attrs =
      if Keyword.get(options, :viewbox, false) do
        viewbox_attr
      else
        ~s(width="#{dimension}" height="#{dimension}" #{viewbox_attr})
      end

    open_tag =
      ~s(<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:ev="http://www.w3.org/2001/xml-events" #{
        dimension_attrs
      } shape-rendering="crispEdges" style="background-color: #{svg_options[:background_color]}">)

    close_tag = ~s(</svg>)

    points =
      matrix
      |> to_list
      |> Stream.map(&to_list/1)
      |> Stream.with_index()
      |> Stream.map(fn {row, index} ->
        y = index + 1

        row
        |> calculate_x_positions
        |> Enum.chunk_every(2)
        |> Enum.zip(Enum.dedup(row))
        |> Enum.map(fn {[start, stop], mode} -> "#{start},#{y - mode} #{stop},#{y - mode}" end)
        |> Enum.concat(["0,#{y}"])
        |> Enum.join(" ")
      end)
      |> Enum.join(" ")

    polyline = ~s(<polyline points="#{points}" fill="#{svg_options[:color]}" />)

    Enum.join([xml_tag, open_tag, polyline, close_tag], "\n")
  end

  defp to_list(tuple) do
    Tuple.to_list(tuple)
  end

  defp calculate_x_positions(row) do
    row
    |> count_consecutive_elements
    |> prepend(0)
    |> accumulate
    |> duplicate_elements
    |> Enum.slice(1..-2)
  end

  defp count_consecutive_elements(row) do
    row
    |> Enum.chunk_by(& &1)
    |> Enum.map(&Enum.count/1)
  end

  defp prepend(list, element) do
    [element | list]
  end

  defp accumulate(list) do
    list |> Enum.scan(&(&1 + &2))
  end

  defp duplicate_elements(list) do
    list |> Enum.flat_map(fn x -> [x, x] end)
  end

  defp set_svg_options(options, matrix_size) do
    options
    |> Map.put_new(:background_color, "#FFF")
    |> Map.put_new(:color, "#000")
    |> set_module_size(matrix_size)
    |> Map.put_new(:shape, "rectangle")
    |> Map.put_new(:size, matrix_size)
  end

  defp set_module_size(%{width: width} = options, matrix_size) when is_integer(width) do
    options
    |> Map.put_new(:module_size, width / matrix_size)
  end

  defp set_module_size(%{width: width} = options, matrix_size) when is_binary(width) do
    options
    |> Map.put_new(:module_size, String.to_integer(width) / matrix_size)
  end

  defp set_module_size(options, _matrix_size) do
    options
    |> Map.put_new(:module_size, 11)
  end
end
