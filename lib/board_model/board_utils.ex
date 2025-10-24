defmodule Board.Utils do
  # import Board
  # import Location
  @moduledoc """
  These are throwaway utility functions that belong in Chessboard.
  Keeping them here because board.ex is too big. Submodule yafeel
  Some are made during initial fn writing, some in repl shenanigans
  """
  @maxSide 8
  @minSide 3

  defguard good_col_n_row(columns, rows) when @maxSide >= columns and columns >= @minSide and @maxSide >= rows and rows >= @minSide

  def nested_convert_to_formal(nested_dumb_placements) do
    nested_dumb_placements |> map_to_each(&(&1 |> Location.formalLocation()))
  end

  @doc """
  How I'm transporting constants across modules
  iex> Board.Utils.get_constant(:pawn_moves, Move)
  [1, 2]
  """
  def get_constant(constant_atom, module) do
    [const] = module.__info__(:attributes)[constant_atom]
    const
  end

  def split_tuple({:ok, struct}), do: struct
  def split_tuple({:error, message}) do
    raise ArgumentError, message: message
  end

  @doc """
  make the board with no pieces on it, just the layout of the board with tiles
  """
  def make2DList(columns, rows) when good_col_n_row(columns, rows), do: rec2DList(columns, rows)
  def make2DList(columns, rows), do: raise BoardError, message: "bad # of rows or columns, Expected 3 to 8 got Row:#{rows}, Col:#{columns}"

  @doc """
  Recursively makes the list of lists that represents the board placements
  maybe make private
  """
  def rec2DList(cols, rows) when cols == 0 or rows == 0, do: []
  def rec2DList(cols, rows), do: :mt |> List.duplicate(cols) |> List.duplicate(rows)

  # these are the help for replace_at, deprecated
  def reversePlacements(urboard) when urboard |> is_struct(), do: %{urboard | placements: urboard.placements |> reversePlacements()}
  def reversePlacements(two_d_list) when is_list(two_d_list), do: two_d_list |> reverseColumns|> reverseRanks

  def reverseRanks(two_d_list), do: Enum.reverse(two_d_list)

  def reverseColumns(two_d_list), do: Enum.map(two_d_list, fn x -> Enum.reverse(x) end)

    @doc """
  Given a rank and a separator, translate and reduce to a string with a translate function depending on the bgame
  """
  def printRank(bgame, rank, sep \\ "\t ")

  def printRank(:chess, rank, sep) do
    Enum.map(rank, fn
      x -> translate(x) <> sep end)
    |> to_string()
  end

  def printRank(:ur, rank, sep) do
    Enum.map(rank, fn
      {tile_spot, piece_spot} = _x -> translate_ur({tile_spot, piece_spot}) <> sep
      x -> translate_ur(x) <> sep
     end) |> to_string()
  end

  @doc """
  Given a pieceColor and pieceType, uses Tile module to get the correct representation
  """
  def translate(pieceColor, pieceType)do
    Tile.renderTile(pieceColor, pieceType)
  end

  def translate(:mt), do: Tile.renderTile(:blue)
  def translate({pieceColor, pieceType}) do
    Tile.renderTile(pieceColor, pieceType)
  end
  def translate(:blue), do: Tile.renderTile(:blue)
  def translate(:orange), do: Tile.renderTile(:orange)

  def translate_ur({tilespot, piecespot}) do
    Tile.renderTile(tilespot, piecespot)
  end

  def translate_ur(alist) when is_list(alist) do
    {color, piece_type} = Enum.at(alist, 0)
    Tile.renderTile(color, piece_type)
  end

  def translate_ur(:mt), do: "?"

  @doc """
  Maps a function to each location on the placements of the board,
  This returns a new placements list.
  """
  def map_to_each(board, fun) do
    Enum.map(board, fn rank -> Enum.map(rank, fn tile -> fun.(tile) end) end)
  end


  @doc """
  Given an atom representing a column, produce the equivalent number starting from 1
  """
  def column_to_int(column) when is_atom(column) do
    case column do
      :a -> 1
      :b -> 2
      :c -> 3
      :d -> 4
      :e -> 5
      :f -> 6
      :g -> 7
      :h -> 8
    end
  end

  @doc """
  Given a num starting from 1 produce the equivalent atom representing the column
  """
  def int_to_column(num) when is_integer(num) do
    case num do
      1 -> :a
      2 -> :b
      3 -> :c
      4 -> :d
      5 -> :e
      6 -> :f
      7 -> :g
      8 -> :h
    end
  end



end
