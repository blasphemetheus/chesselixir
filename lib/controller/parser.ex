defmodule Parser do
  @moduledoc """
  Parser for any of the things
  """
  @doc """
  Parses the raw move WITH KNOWLEDGE of the board, so
  is able to accept raw locations, checking if they belong to the color of the person
  whose turn it is. The parsing fails with an error tuple if any of the info disagrees
  with the validity of the move
  """
  def parseMoveCompare(raw_move, board, turn_color) do
    placements = board.placements

    recurred =
      parse(raw_move, [])
      |> Enum.reject(&(&1 == :space))
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        ls when length(ls) == 1 -> List.first(ls)
        ls when ls |> is_list() -> ls |> List.to_tuple()
      end)
      |> compare_intake(placements, turn_color)
      |> okify()

    IO.puts("recursive version: #{inspect(recurred)}")

    recurred
  end

  def str_to_atom(str) do
    case str do
      "QUEEN" -> :queen
      "ROOK" -> :rook
      "KING" -> :king
      "BISHOP" -> :bishop
      "KNIGHT" -> :knight
      "PAWN" -> :pawn
      _other -> str
    end
  end


  def compare_intake([first | [second | [{"PROMOTE", promote_type}]]], placements, turn_color) do
    moving_placement = Chessboard.get_at(placements, first)

    case moving_placement do
      :mt -> {:error, "empty at start location of move"}
      {^turn_color, piecetype} -> {first, second, piecetype, promote_type |> str_to_atom()}
      {_other_color, _piecetype} -> {:error, "wrong color at indicated start location"}
    end
  end

  def compare_intake([first | [second | [{"CASTLE"}]]], placements, turn_color) do
    moving_placement = Chessboard.get_at(placements, first)

    case moving_placement do
      :mt -> {:error, "empty at start location of move"}
      {^turn_color, piecetype} -> {first, second, piecetype, :nopromote}
      {_other_color, _piecetype} -> {:error, "wrong color at indicated start location"}
    end
  end

  def compare_intake([first | [second | []]], placements, turn_color) do
    moving_placement = Chessboard.get_at(placements, first)

    case moving_placement do
      :mt -> {:error, "empty at start location of move"}
      {^turn_color, piecetype} -> {first, second, piecetype, :nopromote}
      {_other_color, _piecetype} -> {:error, "wrong color at indicated start location"}
    end
  end

  def compare_intake([{_col, _row} = only | []], placements, turn_color) do
    case inferPawnStartLocation(only) do
      {:error, e} ->
        {:error, e}

      start ->
        moving_placement = Chessboard.get_at(placements, start)

        case moving_placement do
          :mt ->
            {:error, "empty at start location"}

          {^turn_color, :pawn} ->
            {start, only, :pawn, :nopromote}

          {^turn_color, other_piece} ->
            {:error, "wrong piece at indicated start location #{inspect(other_piece)}"}

          {_other_color, _piecetype} ->
            {:error, "wrong color at indicated start location"}
        end
    end
  end

  def compare_intake(_any), do: {:error, "cool not valid at compare intake step"}

  @doc """
  given a move in the format {start_lo
  iex> Parser.parseMove("e2 e4")
  {:ok, %{start_loc: {4, 2}, end_loc: {4, 4}, type_at_loc: :pawn}}
  """
  def parseMove(raw_move) do
    # split = raw_move
    # |> String.splitter([" ", ","])
    # |> Enum.take(2)
    # |> okify()

    # IO.puts("split ver: #{inspect(split)}")

    {_start_loc, _end_loc} =
      recurred =
      parse(raw_move, [])
      # |> Enum.split_with(fn x -> intake(x) end)
      |> Enum.reject(&(&1 == :space))
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        ls when length(ls) == 1 -> List.first(ls)
        ls when ls |> is_list() -> ls |> List.to_tuple()
      end)
      |> intake()
      |> okify()

    IO.puts("parsed: #{inspect(recurred)}")

    recurred

    # parse the move
    # if valid, return the start_loc, end_loc, and type_at_loc
    # if invalid, return false
  end

  @doc """
  Given a list of codepoints of the format [:a], converts to tuple
  """
  def intake([first | [second | ["KNIGHT"]]]), do: {first, second, :knight}
  def intake([first | [second | ["ROOK"]]]), do: {first, second, :rook}
  def intake([first | [second | ["BISHOP"]]]), do: {first, second, :bishop}
  def intake([first | [second | ["QUEEN"]]]), do: {first, second, :queen}
  def intake([first | [second | ["KING"]]]), do: {first, second, :king}
  def intake([first | [second | ["PAWN"]]]), do: {first, second, :pawn}
  def intake([first | [second | []]]), do: {first, second, :pawn}
  # for promotion
  def intake([first | [second | [{"PAWN", piece}]]]),
    do: {first, second, :pawn, String.to_atom(piece)}

  # for castling
  def intake([first | [second | [{"KING", "CASTLE"}]]]), do: {first, second, :pawn, :castle}

  def intake([{_col, _row} = only | []]) do
    # so someone tried to input a pawn sprint
    case inferPawnStartLocation(only) do
      {:error, e} -> {:error, e}
      start -> {start, only, :pawn}
    end
  end

  def intake(any), do: {:error, "unknown: #{inspect(any)}"}

  def inferPawnStartLocation({col, 4}), do: {col, 2}
  def inferPawnStartLocation({col, 5}), do: {col, 7}
  def inferPawnStartLocation({col, 3}), do: {col, 2}
  def inferPawnStartLocation({col, 6}), do: {col, 7}
  def inferPawnStartLocation(any), do: {:error, "wrong abbreviated pawn sprint #{inspect(any)}"}

  def okify({:error, e}), do: {:error, e}
  def okify(thing), do: {:ok, thing}

  @doc """
  Given any string, runs through the string recursively byte by byte
  returning the important bits in a list
  NOT THE WAY TO DO IT, BECAUSE WE HAVE STRING.GRAPHEMES which already does that kind of
  """
  def parse("PROMOTE" <> rest, acc), do: parse(rest, ["PROMOTE" | acc])
  def parse("KNIGHT" <> rest, acc), do: parse(rest, ["KNIGHT" | acc])
  def parse("N" <> rest, acc), do: parse(rest, ["KNIGHT" | acc])
  def parse("CASTLE" <> rest, acc), do: parse(rest, ["CASTLE" | acc])
  def parse("L" <> rest, acc), do: parse(rest, ["CASTLE" | acc])
  def parse("QUEEN" <> rest, acc), do: parse(rest, ["QUEEN" | acc])
  def parse("Q" <> rest, acc), do: parse(rest, ["QUEEN" | acc])
  def parse("KING" <> rest, acc), do: parse(rest, ["KING" | acc])
  def parse("K" <> rest, acc), do: parse(rest, ["KING" | acc])
  def parse("BISHOP" <> rest, acc), do: parse(rest, ["BISHOP" | acc])
  def parse("O" <> rest, acc), do: parse(rest, ["BISHOP" | acc])
  def parse("ROOK" <> rest, acc), do: parse(rest, ["ROOK" | acc])
  def parse("R" <> rest, acc), do: parse(rest, ["ROOK" | acc])
  def parse("PAWN" <> rest, acc), do: parse(rest, ["PAWN" | acc])
  def parse("P" <> rest, acc), do: parse(rest, ["PAWN" | acc])

  def parse("A" <> rest, acc), do: parse(:col, rest, [:a | acc])
  def parse("B" <> rest, acc), do: parse(:col, rest, [:b | acc])
  def parse("C" <> rest, acc), do: parse(:col, rest, [:c | acc])
  def parse("D" <> rest, acc), do: parse(:col, rest, [:d | acc])
  def parse("E" <> rest, acc), do: parse(:col, rest, [:e | acc])
  def parse("F" <> rest, acc), do: parse(:col, rest, [:f | acc])
  def parse("G" <> rest, acc), do: parse(:col, rest, [:g | acc])
  def parse("H" <> rest, acc), do: parse(:col, rest, [:h | acc])
  def parse(" " <> rest, acc), do: parse(rest, [:space | acc])
  def parse("", acc), do: Enum.reverse(acc)

  def parse(<<codepoint>> <> rest, acc) do
    parse(rest, [codepoint | acc])
  end

  def parse(string, _acc) do
    _next = String.next_grapheme(string)
    #bin_size = String.next_grapheme_size(string)
    IO.puts("________")
  end

  def parse(:col, "1" <> rest, acc), do: parse(rest, [1 | acc])
  def parse(:col, "2" <> rest, acc), do: parse(rest, [2 | acc])
  def parse(:col, "3" <> rest, acc), do: parse(rest, [3 | acc])
  def parse(:col, "4" <> rest, acc), do: parse(rest, [4 | acc])
  def parse(:col, "5" <> rest, acc), do: parse(rest, [5 | acc])
  def parse(:col, "6" <> rest, acc), do: parse(rest, [6 | acc])
  def parse(:col, "7" <> rest, acc), do: parse(rest, [7 | acc])
  def parse(:col, "8" <> rest, acc), do: parse(rest, [8 | acc])
  def parse(:col, "", acc), do: Enum.reverse(acc)
  def parse(:col, _rest, acc), do: Enum.reverse(acc)

  #####################
  def parseBoardFromString(bin) when bin |> is_binary() do
    bin
    |> String.graphemes()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.chunk_every(8)
    |> Enum.map(fn x -> x |> Enum.map(&parseSquare/1) end)
  end

  def parseSquare(piece) do
    case piece do
      "◻" -> :mt
      "◼" -> :mt
      "♔" -> {:blue, :king}
      "♕" -> {:blue, :queen}
      "♖" -> {:blue, :rook}
      "♗" -> {:blue, :bishop}
      "♘" -> {:blue, :knight}
      "♙" -> {:blue, :pawn}
      "♚" -> {:orange, :king}
      "♛" -> {:orange, :queen}
      "♜" -> {:orange, :rook}
      "♝" -> {:orange, :bishop}
      "♞" -> {:orange, :knight}
      "♟︎" -> {:orange, :pawn}
      any -> raise ArgumentError, message: "invalid string #{inspect(any)}"
    end
  end
end
