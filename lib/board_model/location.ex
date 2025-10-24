# a location is a useful tuple, but it can be found in a number of formats
# - the interior of the board, so a stored location. This uses integers starting from 0 and going up. That is how
#   items in a list are referenced and it is not negotiable as I intend to use the List functionality present in Elixir
# - the general chess world, which uses the column identifiers a through h to represent the 8 columns of the board
#   and then the numbers 1 through 8 to represent the ranks of the board. I want to be able to use this representation
#   in tests for ease of thought.

# I could make a third intermediary type but I think that is a bad idea. I will stick with these two types but make
# it so my program will accept both? is that a bad idea? I dunno. This file is kind of like a util file for
# location functions, checks, conversions, or anything similar

# The two types are "dumb" and "formal" locations. There is no intermediary. They also alternate which one is a row.
# this is because I'm being Annoying lol (also people say A1 for instance but I'd like to be able to visualize in
# ascii the board easily so the way the dumb one works it'd be A1 (flip)-> 1A -> 0,0)

# accepts a dumb location or a clean location and spits out a dumb location
# will accept a tuple or two arguments representing a row and column
defmodule Location do
  @moduledoc """
  All about Locations
  """

  # (dumb locations are not intuitive,
  #         {:a, 1} does NOT translate to {0, 0} as it turns out)
  #         (it translates to {0, 7} because of the way the board is stored)

  # transpose and switch the row and columns
  def dumbLocation({formal_col, formal_row}) when formal_col in [:a, :b, :c, :d, :e, :f, :g, :h] and is_integer(formal_row) do
    {dumbRow(formal_row), dumbColumn(formal_col)}
  end

  def dumbLocation(_), do: raise ArgumentError, message: "did not pass in a formal location"

  # given a column in the format :a, :b, :c ... :h or 1, 2, 3 ... 8 will return the numbers starting from 0
  defp dumbColumn(clean_format_col) do
    case clean_format_col do
      :a -> 0
      :b -> 1
      :c -> 2
      :d -> 3
      :e -> 4
      :f -> 5
      :g -> 6
      :h -> 7
      _ -> raise ArgumentError, message: "didn't pass in a formal column [:a, :b, ... :h]"
    end
  end

  # converts a formal row to a dumb row (starting from 1 to starting from 0)
  defp dumbRow(formal_row), do: formal_row - 1

  # converts a dumb location into a formal location
  @doc """
  Given a dumb location, returns a formal location

  iex> Location.formalLocation({0, 0})
  {:a, 1}
  """
  def formalLocation({dumb_row, dumb_col}) when not is_integer(dumb_row) or not is_integer(dumb_col) do
    raise ArgumentError, message: "dumb location is not well-formed (doesn't have 2 integers)"
  end

  def formalLocation({dumb_row, dumb_col}) do
    {formalCol(dumb_col), formalRow(dumb_row)}
  end

  def formalCol(dumb_col) do
    case dumb_col do
      0 -> :a
      1 -> :b
      2 -> :c
      3 -> :d
      4 -> :e
      5 -> :f
      6 -> :g
      7 -> :h
      _ -> raise ArgumentError, message: "wrong dumb_column integer"
    end
  end

  def formalRow(dumb_row), do: dumb_row + 1

  def nextTo(col, other_col) when is_atom(col) and is_atom(other_col), do: nextTo(dumbColumn(col), dumbColumn(other_col))
  def nextTo(row, other_row) when is_integer(row) and is_integer(other_row), do: abs(row - other_row) == 1

end # end o module
